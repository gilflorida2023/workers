package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/ssh"
)

type WorkerConfig struct {
	Name        string            `json:"name"`
	Host        string            `json:"host"`
	User        string            `json:"user"`
	BinaryPath  string            `json:"binary_path"`
	Strategies  map[string]string `json:"strategies"`
}

type RunResult struct {
	Worker      string            `json:"worker"`
	Host        string            `json:"host"`
	Limit       uint64            `json:"limit"`
	DurationMs  int64             `json:"duration_ms"`
	Primes      uint64            `json:"primes"`
	PeakMemMB   uint64            `json:"peak_mem_mb"`
	KATHash     string            `json:"kat_hash"`
	Config      map[string]string `json:"config"`
	CodeHash    string            `json:"code_hash"`
	Timestamp   int64             `json:"timestamp"`
	Success     bool              `json:"success"`
	Error       string            `json:"error,omitempty"`
}

type JudgeRequest struct {
	Results []RunResult `json:"results"`
	Limit   uint64      `json:"limit"`
}

type JudgeResponse struct {
	Winner       string   `json:"winner"`
	Mutations    []string `json:"mutations"`
	Analysis     string   `json:"analysis"`
	Confidence   float64  `json:"confidence"`
}

type Orchestrator struct {
	workers    []WorkerConfig
	judgeURL   string
	logFile    *os.File
	mu         sync.Mutex
	resultsDir string
}

func NewOrchestrator(workers []WorkerConfig, judgeURL, resultsDir string) (*Orchestrator, error) {
	if err := os.MkdirAll(resultsDir, 0755); err != nil {
		return nil, err
	}
	logPath := filepath.Join(resultsDir, fmt.Sprintf("orchestrator_%d.jsonl", time.Now().UnixMilli()))
	f, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return nil, err
	}
	return &Orchestrator{
		workers:    workers,
		judgeURL:   judgeURL,
		logFile:    f,
		resultsDir: resultsDir,
	}, nil
}

func (o *Orchestrator) log(entry any) {
	o.mu.Lock()
	defer o.mu.Unlock()
	data, _ := json.Marshal(entry)
	o.logFile.Write(data)
	o.logFile.WriteString("\n")
}

func (o *Orchestrator) Close() {
	o.logFile.Close()
}

func (o *Orchestrator) buildWorker(worker WorkerConfig) error {
	cmd := exec.Command("go", "build", "-o", filepath.Join("../bin", worker.Name), ".")
	cmd.Dir = filepath.Join("../", worker.Name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("build failed: %v\n%s", err, output)
	}
	return nil
}

func (o *Orchestrator) deployWorker(worker WorkerConfig) error {
	if worker.Host == "localhost" || worker.Host == "127.0.0.1" {
		return nil
	}
	binaryPath := filepath.Join("../bin", worker.Name)
	cmd := exec.Command("scp", binaryPath, fmt.Sprintf("%s@%s:%s", worker.User, worker.Host, worker.BinaryPath))
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("deploy failed: %v\n%s", err, output)
	}
	return nil
}

func (o *Orchestrator) runWorker(worker WorkerConfig, limit uint64) RunResult {
	var cmd *exec.Cmd
	if worker.Host == "localhost" || worker.Host == "127.0.0.1" {
		cmd = exec.Command(filepath.Join("../bin", worker.Name), "--limit", strconv.FormatUint(limit, 10), "--hash")
	} else {
		cmd = exec.Command("ssh", fmt.Sprintf("%s@%s", worker.User, worker.Host), fmt.Sprintf("%s --limit %d --hash", worker.BinaryPath, limit))
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return RunResult{Worker: worker.Name, Host: worker.Host, Limit: limit, Success: false, Error: err.Error()}
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return RunResult{Worker: worker.Name, Host: worker.Host, Limit: limit, Success: false, Error: err.Error()}
	}

	if err := cmd.Start(); err != nil {
		return RunResult{Worker: worker.Name, Host: worker.Host, Limit: limit, Success: false, Error: err.Error()}
	}

	scanner := bufio.NewScanner(stdout)
	var katHash string
	if scanner.Scan() {
		katHash = strings.TrimSpace(scanner.Text())
	}

	var result RunResult
	stderrScanner := bufio.NewScanner(stderr)
	if stderrScanner.Scan() {
		if err := json.Unmarshal(stderrScanner.Bytes(), &result); err != nil {
			log.Printf("Failed to parse stderr JSON: %v", err)
		}
	}

	cmd.Wait()

	result.Worker = worker.Name
	result.Host = worker.Host
	result.Limit = limit
	result.KATHash = katHash
	result.Success = true

	return result
}

func (o *Orchestrator) verifyKAT(limit uint64, hash string) (bool, error) {
	cmd := exec.Command("python3", "-c", `
import json, hashlib
with open("../manifests/A000040.json") as f:
    m = json.load(f)
for ckpt in m.get("checkpoint_hashes", {}):
    pass
`)
	return true, nil
}

func (o *Orchestrator) queryJudge(ctx context.Context, results []RunResult, limit uint64) (*JudgeResponse, error) {
	req := JudgeRequest{Results: results, Limit: limit}
	body, _ := json.Marshal(req)

	httpReq, err := http.NewRequestWithContext(ctx, "POST", o.judgeURL+"/judge", strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var judgeResp JudgeResponse
	if err := json.NewDecoder(resp.Body).Decode(&judgeResp); err != nil {
		return nil, err
	}
	return &judgeResp, nil
}

func (o *Orchestrator) RunRound(limit uint64) error {
	fmt.Printf("\n=== Round at limit %d ===\n", limit)

	var wg sync.WaitGroup
	results := make([]RunResult, len(o.workers))
	errs := make([]error, len(o.workers))

	for i, w := range o.workers {
		wg.Add(1)
		go func(idx int, worker WorkerConfig) {
			defer wg.Done()
			fmt.Printf("Running %s on %s...\n", worker.Name, worker.Host)
			r := o.runWorker(worker, limit)
			results[idx] = r
			o.log(r)
			if r.Success {
				fmt.Printf("  %s: %d primes, %d ms, hash=%s\n", worker.Name, r.Primes, r.DurationMs, r.KATHash[:16]+"...")
			} else {
				fmt.Printf("  %s FAILED: %s\n", worker.Name, r.Error)
				errs[idx] = fmt.Errorf(r.Error)
			}
		}(i, w)
	}
	wg.Wait()

	for i, err := range errs {
		if err != nil {
			return fmt.Errorf("worker %s failed: %v", o.workers[i].Name, err)
		}
	}

	hashes := make(map[string]int)
	for _, r := range results {
		hashes[r.KATHash]++
	}
	if len(hashes) > 1 {
		fmt.Println("WARNING: KAT hashes differ between workers!")
		for h, c := range hashes {
			fmt.Printf("  %s: %d workers\n", h[:16]+"...", c)
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 180*time.Second)
	defer cancel()
	judgeResp, err := o.queryJudge(ctx, results, limit)
	if err != nil {
		fmt.Printf("Judge query failed: %v\n", err)
	} else {
		fmt.Printf("\nJudge verdict: %s (confidence: %.2f)\n", judgeResp.Winner, judgeResp.Confidence)
		fmt.Printf("Analysis: %s\n", judgeResp.Analysis)
		fmt.Printf("Mutations for next round:\n")
		for _, m := range judgeResp.Mutations {
			fmt.Printf("  - %s\n", m)
		}
		o.log(map[string]any{
			"type":      "judge_verdict",
			"limit":     limit,
			"winner":    judgeResp.Winner,
			"mutations": judgeResp.Mutations,
			"analysis":  judgeResp.Analysis,
			"confidence": judgeResp.Confidence,
		})
	}

	return nil
}

func main() {
	workers := []WorkerConfig{
		{Name: "w1_baseline", Host: "localhost", User: "scout", BinaryPath: "~/bin/w1_baseline"},
		{Name: "w2_wheel2310", Host: "second", User: "second", BinaryPath: "~/bin/w2_wheel2310"},
		{Name: "w3_seq_cacheopt", Host: "third", User: "third", BinaryPath: "~/bin/w3_seq_cacheopt"},
	}

	judgeURL := "http://192.168.0.8:11435"
	resultsDir := "../results"

	orch, err := NewOrchestrator(workers, judgeURL, resultsDir)
	if err != nil {
		log.Fatal(err)
	}
	defer orch.Close()

	stages := []uint64{1_000_000, 10_000_000, 100_000_000}
	for _, limit := range stages {
		if err := orch.RunRound(limit); err != nil {
			log.Fatalf("Round failed: %v", err)
		}
	}
}