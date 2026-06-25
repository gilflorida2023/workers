module github.com/primeforge/orchestrator

go 1.25.0

require (
	github.com/primeforge/services/compile v0.0.0
	github.com/primeforge/services/execute v0.0.0
	github.com/primeforge/services/kat_verify v0.0.0
	github.com/primeforge/services/ollama_client v0.0.0
	github.com/primeforge/shared v0.0.0
)

require (
	golang.org/x/crypto v0.53.0 // indirect
	golang.org/x/sys v0.46.0 // indirect
)

replace (
	github.com/primeforge/services/compile => ../services/compile
	github.com/primeforge/services/execute => ../services/execute
	github.com/primeforge/services/kat_verify => ../services/kat_verify
	github.com/primeforge/services/ollama_client => ../services/ollama_client
	github.com/primeforge/shared => ../shared
)
