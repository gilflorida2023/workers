module github.com/primeforge/services/judge

go 1.22

replace github.com/primeforge/shared => ../../shared

replace github.com/primeforge/services/ollama_client => ../ollama_client

require github.com/primeforge/services/ollama_client v0.0.0
