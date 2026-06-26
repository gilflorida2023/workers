package main

import (
	"bytes"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
)

const (
	CGIDir = "/home/scout/projects/workers/scout/cgi-bin"
)

func main() {
	http.HandleFunc("/cgi-bin/", func(w http.ResponseWriter, r *http.Request) {
		toolPath := strings.TrimPrefix(r.URL.Path, "/cgi-bin/")
		if toolPath == "" {
			http.Error(w, "Tool path required", http.StatusBadRequest)
			return
		}

		scriptPath := filepath.Join(CGIDir, toolPath)
		if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
			http.Error(w, "Tool not found", http.StatusNotFound)
			return
		}

		env := os.Environ()

		// Read body first
		bodyBytes, _ := io.ReadAll(r.Body)

		cmd := exec.Command(scriptPath)
		cmd.Env = env
		cmd.Dir = CGIDir

		// Use bytes.Reader for stdin instead of pipe
		cmd.Stdin = bytes.NewReader(bodyBytes)

		stdout, err := cmd.StdoutPipe()
		if err != nil {
			http.Error(w, "CGI stdout pipe failed", http.StatusInternalServerError)
			return
		}
		stderr, err := cmd.StderrPipe()
		if err != nil {
			http.Error(w, "CGI stderr pipe failed", http.StatusInternalServerError)
			return
		}

		if err := cmd.Start(); err != nil {
			http.Error(w, "CGI start failed", http.StatusInternalServerError)
			return
		}

		log.Printf("CGI started [%s], pid=%d", toolPath, cmd.Process.Pid)

		var stdoutData, stderrData []byte
		var wg sync.WaitGroup
		wg.Add(2)
		go func() {
			defer wg.Done()
			stdoutData, _ = io.ReadAll(stdout)
			log.Printf("CGI stdout read done [%s]: %d bytes", toolPath, len(stdoutData))
		}()
		go func() {
			defer wg.Done()
			stderrData, _ = io.ReadAll(stderr)
			log.Printf("CGI stderr read done [%s]: %d bytes", toolPath, len(stderrData))
		}()
		wg.Wait()

		log.Printf("CGI wait done [%s]", toolPath)
		cmd.Wait()

		log.Printf("CGI exited [%s]: exitCode=%d", toolPath, cmd.ProcessState.ExitCode())

		w.Header().Set("Content-Type", "application/json")
		w.Write(stdoutData)

		if len(stderrData) > 0 {
			log.Printf("CGI stderr [%s]: %s", toolPath, string(stderrData))
		}
	})

	log.Println("Test server starting on :8081")
	http.ListenAndServe(":8081", nil)
}
