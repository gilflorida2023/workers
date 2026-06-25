package main

import (
	"encoding/json"
	"fmt"
	"os"
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

func main() {
	if len(os.Args) < 3 {
		fmt.Println("usage: compile <worker|baseline> <directory>")
		os.Exit(1)
	}
	var result CompileResult
	if os.Args[1] == "worker" {
		result = CompileWorker(os.Args[2])
	} else if os.Args[1] == "baseline" {
		result = CompileBaseline(os.Args[2])
	} else {
		fmt.Fprintf(os.Stderr, "unknown type: %s\n", os.Args[1])
		os.Exit(1)
	}
	json.NewEncoder(os.Stdout).Encode(result)
	if !result.Success {
		os.Exit(1)
	}
}