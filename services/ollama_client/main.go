package main

import (
	"context"
	"fmt"
	"os"
	"time"

	ollama "github.com/primeforge/services/ollama_client/ollama"
)

func main() {
	if len(os.Args) < 4 {
		fmt.Println("usage: ollama_client <host> <model> <prompt> [--json]")
		os.Exit(1)
	}
	host := os.Args[1]
	model := os.Args[2]
	prompt := os.Args[3]
	formatJSON := false
	if len(os.Args) > 4 && os.Args[4] == "--json" {
		formatJSON = true
	}
	client := ollama.NewOllamaClient(30 * time.Second)
	ctx := context.Background()
	resp, err := client.Call(ctx, host, model, prompt, formatJSON)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(resp)
}