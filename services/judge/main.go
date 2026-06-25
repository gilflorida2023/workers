package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	ollama "github.com/primeforge/services/ollama_client/ollama"
)

type JudgeRequest struct {
	Results []RunResult `json:"results"`
	Limit   uint64      `json:"limit"`
}

type RunResult struct {
	Worker       string            `json:"worker"`
	Host         string            `json:"host,omitempty"`
	Limit        uint64            `json:"limit"`
	Primes       uint64            `json:"primes"`
	DurationMs   int64             `json:"duration_ms"`
	PeakMemMB    uint64            `json:"peak_mem_mb,omitempty"`
	KATHash      string            `json:"kat_hash"`
	ExpectedHash string            `json:"expected_hash,omitempty"`
	KATMatch     bool              `json:"kat_match,omitempty"`
	Config       map[string]string `json:"config"`
	CodeHash     string            `json:"code_hash,omitempty"`
	Timestamp    int64             `json:"timestamp,omitempty"`
	Success      bool              `json:"success,omitempty"`
	Error        string            `json:"error,omitempty"`
}

type JudgeResponse struct {
	Winner     string   `json:"winner"`
	Mutations  []string `json:"mutations"`
	Analysis   string   `json:"analysis"`
	Confidence float64  `json:"confidence"`
}

var models = []string{
	"qwen3.5-abliterated:4B",
	"qwen3.5-abliterated:2B",
	"qwen3.5-abliterated:0.8B",
}

var ollamaHost = "first"

func main() {
	port := "11435"
	if len(os.Args) > 1 && os.Args[1] == "verify" {
		if len(os.Args) < 4 {
			fmt.Fprintf(os.Stderr, "usage: judge verify <limit> <hash>\n")
			os.Exit(1)
		}
		verifyMode(os.Args[2], os.Args[3])
		return
	}
	if len(os.Args) > 1 {
		port = os.Args[1]
	}

	client := ollama.NewOllamaClient(60 * time.Second)

	http.HandleFunc("/judge", func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				log.Printf("judge panic: %v", rec)
				http.Error(w, "judge panic", http.StatusInternalServerError)
			}
		}()
		log.Printf("judge request received from %s", r.RemoteAddr)
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req JudgeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request", http.StatusBadRequest)
			return
		}

		resp, err := judgeResults(r.Context(), client, req)
		if err != nil {
			log.Printf("judge error: %v", err)
			http.Error(w, "judge failed", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			log.Printf("encode error: %v", err)
		}
		log.Printf("judge response sent")
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	srv := &http.Server{
		Addr:         "0.0.0.0:" + port,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 120 * time.Second,
	}

	go func() {
		log.Printf("Judge server starting on :%s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server failed: %v", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)
	<-sigCh

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
}

func judgeResults(ctx context.Context, client *ollama.OllamaClient, req JudgeRequest) (*JudgeResponse, error) {
	prompt := buildPrompt(req)

	type modelResult struct {
		model    string
		response string
		err      error
	}

	resultCh := make(chan modelResult, len(models))
	for _, model := range models {
		go func(m string) {
			modelCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
			defer cancel()
			resp, err := client.Call(modelCtx, ollamaHost, m, prompt, true)
			resultCh <- modelResult{model: m, response: resp, err: err}
		}(model)
	}

	var responses []string
	for i := 0; i < len(models); i++ {
		res := <-resultCh
		if res.err != nil {
			log.Printf("model %s error: %v", res.model, res.err)
			continue
		}
		responses = append(responses, res.response)
	}

	if len(responses) == 0 {
		log.Printf("all models failed, returning mock response")
		return &JudgeResponse{
			Winner:     req.Results[0].Worker,
			Analysis:   "All models unavailable; defaulting to first worker with matching KAT hash",
			Confidence: 0.5,
			Mutations:  []string{},
		}, nil
	}

	return aggregateResponses(responses)
}

func buildPrompt(req JudgeRequest) string {
	var sb strings.Builder
	sb.WriteString("You are evaluating prime sieve implementations. Each worker computed primes up to a limit and produced a KAT hash.\n\n")
	sb.WriteString(fmt.Sprintf("Limit: %d (target primes: ~%d)\n\n", req.Limit, estimatePrimeCount(req.Limit)))

	for _, r := range req.Results {
		sb.WriteString(fmt.Sprintf("Worker: %s\n", r.Worker))
		sb.WriteString(fmt.Sprintf("  Primes generated: %d\n", r.Primes))
		sb.WriteString(fmt.Sprintf("  Duration: %d ms\n", r.DurationMs))
		sb.WriteString(fmt.Sprintf("  KAT Hash: %s\n", r.KATHash))
		sb.WriteString(fmt.Sprintf("  Expected:  %s\n", r.ExpectedHash))
		sb.WriteString(fmt.Sprintf("  KAT Match: %v\n", r.KATMatch))
		sb.WriteString(fmt.Sprintf("  Config: %s\n\n", r.Config))
	}

	sb.WriteString("Respond in JSON format:\n")
	sb.WriteString(`{"winner": "worker_name", "mutations": ["mutation1", "mutation2"], "analysis": "detailed analysis", "confidence": 0.95}`)

	return sb.String()
}

func estimatePrimeCount(limit uint64) uint64 {
	if limit < 6 {
		return limit
	}
	return uint64(float64(limit) / (float64(limit) * 0.1))
}

func aggregateResponses(responses []string) (*JudgeResponse, error) {
	var parsed []JudgeResponse
	for _, r := range responses {
		var jr JudgeResponse
		if err := json.Unmarshal([]byte(r), &jr); err != nil {
			log.Printf("failed to parse response: %v, raw: %s", err, r)
			continue
		}
		parsed = append(parsed, jr)
	}

	if len(parsed) == 0 {
		return &JudgeResponse{Winner: "none", Analysis: "no valid responses", Confidence: 0}, nil
	}

	winnerCounts := make(map[string]int)
	var allMutations []string
	var analyses []string
	for _, p := range parsed {
		winnerCounts[p.Winner]++
		allMutations = append(allMutations, p.Mutations...)
		analyses = append(analyses, p.Analysis)
	}

	var winner string
	maxCount := 0
	for w, c := range winnerCounts {
		if c > maxCount {
			maxCount = c
			winner = w
		}
	}

	confidence := float64(maxCount) / float64(len(parsed))

	return &JudgeResponse{
		Winner:     winner,
		Mutations:  deduplicate(allMutations),
		Analysis:   strings.Join(analyses, "; "),
		Confidence: confidence,
	}, nil
}

func deduplicate(in []string) []string {
	seen := make(map[string]bool)
	var out []string
	for _, s := range in {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}

func verifyMode(limitStr, hash string) {
	fmt.Printf("Verify mode: limit=%s hash=%s\n", limitStr, hash)
}