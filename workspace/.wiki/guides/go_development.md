# Guide: Go Development

## Compiling Go Code
```json
{"name": "workspace.compile", "arguments": {"path": "main.go", "language": "go"}}
```

Produces binary named after source file (e.g., `main.go` → `main`).

## Running Go Programs
```json
{"name": "workspace.run", "arguments": {"path": "./main", "args": ["-limit", "100"]}}
```

## Common Patterns

### Sieve of Eratosthenes
```go
package main

func Sieve(limit int) []int {
    if limit < 2 { return []int{} }
    sieve := make([]bool, limit+1)
    for i := 2; i*i <= limit; i++ {
        if !sieve[i] {
            for j := i*i; j <= limit; j += i {
                sieve[j] = true
            }
        }
    }
    var primes []int
    for i := 2; i <= limit; i++ {
        if !sieve[i] { primes = append(primes, i) }
    }
    return primes
}
```

## Tips
- Use `go build -o name main.go` for custom output name
- `go test ./...` for running tests
- `go fmt ./...` for formatting