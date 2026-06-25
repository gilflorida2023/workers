package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type RunResult struct {
	Worker      string  `json:"worker"`
	Host        string  `json:"host"`
	Limit       uint64  `json:"limit"`
	DurationMs  int64   `json:"duration_ms"`
	Primes      int64   `json:"primes"`
	PeakMemMB   float64 `json:"peak_mem_mb"`
	KATHash     string  `json:"kat_hash"`
	Config      string  `json:"config"`
	Success     bool    `json:"success"`
	Error       string  `json:"error,omitempty"`
}

type WorkerOutput struct {
	DurationMs  int64   `json:"duration_ms"`
	Primes      int64   `json:"primes"`
	PeakMemMB   float64 `json:"peak_mem_mb"`
	Config      string  `json:"config"`
}

func Execute(binaryPath string, limit uint64) (RunResult, error) {
	cmd := exec.Command(binaryPath, fmt.Sprintf("--limit=%d", limit), "--hash")
	cmd.Env = append(os.Environ(), "GOGC=off")
	
	stdout, stderr, err := runWithCapture(cmd)
	
	result := RunResult{
		Limit:      limit,
		KATHash:    strings.TrimSpace(stdout),
		Success:    err == nil,
	}
	
	if err != nil {
		result.Error = fmt.Sprintf("execution failed: %v\nstderr: %s", err, stderr)
		return result, nil
	}
	
	var output WorkerOutput
	if err := json.Unmarshal([]byte(stderr), &output); err != nil {
		result.Error = fmt.Sprintf("failed to parse stderr JSON: %v\nstderr: %s", err, stderr)
		result.Success = false
		return result, nil
	}
	
	result.DurationMs = output.DurationMs
	result.Primes = output.Primes
	result.PeakMemMB = output.PeakMemMB
	result.Config = output.Config
	
	return result, nil
}

func runWithCapture(cmd *exec.Cmd) (string, string, error) {
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return "", "", err
	}
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return "", "", err
	}
	
	if err := cmd.Start(); err != nil {
		return "", "", err
	}
	
	stdoutBytes := make([]byte, 0, 1024)
	stderrBytes := make([]byte, 0, 1024)
	
	done := make(chan error, 1)
	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := stdoutPipe.Read(buf)
			if n > 0 {
				stdoutBytes = append(stdoutBytes, buf[:n]...)
			}
			if err != nil {
				break
			}
		}
	}()
	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := stderrPipe.Read(buf)
			if n > 0 {
				stderrBytes = append(stderrBytes, buf[:n]...)
			}
			if err != nil {
				break
			}
		}
	}()
	
	err = cmd.Wait()
	done <- err
	
	return string(stdoutBytes), string(stderrBytes), err
}

func main() {}