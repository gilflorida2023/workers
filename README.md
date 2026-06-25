# Prime Forge - Sieve Benchmark with KAT Verification & LLM Judge

## Architecture
```
workers (3) → orchestrator → judge (3 Ollama models)
     │              │              │
     ▼              ▼              ▼
  KAT hash    trace JSONL      verdict + mutations
```

## Manifest Tiers (A000040)
| Tier | Limit | Primes | KAT Hash (SHA-256) |
|------|-------|--------|---------------------|
| min | 541 | 100 | 5991e67de21b5e0aac4191be06e69b5e32e8431858a108c4029906aaa96a1371 |
| ci_smoke | 7919 | 1,000 | 18ac898998c81cb9eb52d37be6cd452a3b19babedbdd5cc6e8ffff20e7c2b048 |
| dev | 1299709 | 100,000 | 19778d8659445c92f6f2b1f5deed0932fbd2ab31fe07cc714ef64847eb1a8236 |

## Workers
| Binary | Source | Wheel | Mode |
|--------|--------|-------|------|
| `w1_baseline` | `baseline/` | 210 | parallel |
| `w2_wheel2310` | `worker1/` | 2310 | parallel (`ForEachPrime`) |
| `w3_seq_cacheopt` | `worker2/` | 2310 | sequential (`ForEachPrimeSequential`) |

## Build Commands
```bash
cd /home/scout/projects/workers

# Core library (shared)
go build ./shared/sieve

# Workers
go build -o bin/w1_baseline ./baseline
go build -o bin/w2_wheel2310 ./worker1
go build -o bin/w3_seq_cacheopt ./worker2

# Services
go build -o bin/kat_verify ./services/kat_verify
go build -o bin/ollama_client ./services/ollama_client
go build -o bin/compile ./services/compile
go build -o bin/execute ./services/execute
go build -o bin/judge ./services/judge

# Orchestrator
go build -o bin/orchestrator ./orchestrator
```

## Run

### 1. Start Judge (requires Ollama on first:11434 with qwen3.5-abliterated models)
```bash
./bin/judge 11435
```

### 2. Run Orchestrator
```bash
./bin/orchestrator
```

### 3. Verify KAT manually
```bash
./bin/kat_verify 541 5991e67de21b5e0aac4191be06e69b5e32e8431858a108c4029906aaa96a1371
```

## Worker Flags
```
--limit N        : sieve limit (default 541)
--hash           : print KAT hash to stdout
--verify         : self-verify via kat_verify tool
```

## Judge API
- `POST /judge` - JudgeRequest{Results, Limit} → JudgeResponse{Winner, Mutations, Analysis, Confidence}
- `GET /health` - Health check
- CLI: `judge verify <limit> <hash>`