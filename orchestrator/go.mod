module github.com/primeforge/orchestrator

go 1.22

require (
	github.com/primeforge/services/ollama_client v0.0.0
	github.com/primeforge/services/compile v0.0.0
	github.com/primeforge/services/execute v0.0.0
	github.com/primeforge/services/kat_verify v0.0.0
	github.com/primeforge/shared v0.0.0
)

replace (
	github.com/primeforge/services/ollama_client => ../services/ollama_client
	github.com/primeforge/services/compile => ../services/compile
	github.com/primeforge/services/execute => ../services/execute
	github.com/primeforge/services/kat_verify => ../services/kat_verify
	github.com/primeforge/shared => ../shared
)