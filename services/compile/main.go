package main

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"time"
)

type CompileResult struct {
	Success   bool
	BinaryPath string
	Error     string
	DurationMs int64
}

func CompileWorker(workerDir string) CompileResult {
	start := time.Now()
	
	binaryPath := filepath.Join(workerDir, "worker")
	
	cmd := exec.Command("go", "build", "-o", binaryPath, ".")
	cmd.Dir = workerDir
	output, err := cmd.CombinedOutput()
	
	durationMs := time.Since(start).Milliseconds()
	
	if err != nil {
		return CompileResult{
			Success:    false,
			Error:      fmt.Sprintf("compile failed: %s\n%s", err, string(output)),
			DurationMs: durationMs,
		}
	}
	
	return CompileResult{
		Success:    true,
		BinaryPath: binaryPath,
		DurationMs: durationMs,
	}
}

func CompileBaseline(baselineDir string) CompileResult {
	start := time.Now()
	
	binaryPath := filepath.Join(baselineDir, "baseline")
	
	cmd := exec.Command("go", "build", "-o", binaryPath, ".")
	cmd.Dir = baselineDir
	output, err := cmd.CombinedOutput()
	
	durationMs := time.Since(start).Milliseconds()
	
	if err != nil {
		return CompileResult{
			Success:    false,
			Error:      fmt.Sprintf("baseline compile failed: %s\n%s", err, string(output)),
			DurationMs: durationMs,
		}
	}
	
	return CompileResult{
		Success:    true,
		BinaryPath: binaryPath,
		DurationMs: durationMs,
	}
}

func main() {}