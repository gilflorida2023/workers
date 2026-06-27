# Prime Forge — Coevolutionary Code Arena

Two AI worker agents (LLMs via Ollama) compete to optimize a prime sieve algorithm in a Git-audited competitive arena. Each worker iteratively improves `internal/sieve/sieve.go`, submits code, and is scored on originality, correctness, speed, and memory vs a shared baseline. Winners advance through tiered problem difficulties.

## Architecture

```
┌─────────────┐     ┌──────────────────────────────┐     ┌──────────┐
│  Ollama W1  │────▶│  Scout Server (Go :8080)      │◀────│ Ollama W2│
│  worker1    │     │  ├─ CGI dispatcher            │     │ worker2  │
│  :11434     │     │  ├─ arena/ (8 CGI scripts)    │     │ :11434   │
└─────────────┘     │  ├─ mcp/tools/ (tool registry)│     └──────────┘
                    │  ├─ /status, /events, /health  │
                    │  └─ Git sandbox per worker     │
                    └──────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Leaderboard    │
                    │  (JSON file)    │
                    └─────────────────┘
```

The Scout server runs on port 8080 and dispatches tool calls to CGI shell scripts. Worker agents connect via Ollama's `/api/chat` with tool calling support.

## Project Structure

```
scout/                          # Scout server (Go, CGI)
├── scout.go                    # Server entry point (port 8080)
├── start_scout.sh              # Initialize arena + start server
├── bin/scout                   # Compiled server binary
├── cgi-bin/
│   ├── mcp/tools/
│   │   ├── list.sh             # Tool definitions (35+ tools)
│   │   └── call.sh             # Tool routing to CGI scripts
│   └── arena/
│       ├── get_context.sh      # Return baseline code + tier info
│       ├── read_file.sh        # Read worker sandbox file
│       ├── write_file.sh       # Write worker sandbox file
│       ├── submit.sh           # Git-commit worker code
│       ├── run_match.sh        # Full match orchestrator
│       ├── leaderboard.sh      # Return leaderboard.json
│       ├── status.sh           # Worker status + history
│       └── match_result.sh     # Last match result
├── contexts/arena/
│   ├── baseline/               # Reference sieve implementation (Go module)
│   │   ├── main.go             # CLI entry point (stable, worker-visible)
│   │   ├── go.mod              # module simplesieve
│   │   └── internal/sieve/sieve.go  # Sieve algorithm (worker-editable)
│   ├── worker1/                # Git sandbox for worker 1
│   ├── worker2/                # Git sandbox for worker 2
│   ├── tier.json               # Current problem tier
│   └── matches.jsonl           # Match history
├── leaderboard.json            # Persistent leaderboard state
└── locks/                      # Flock-based mutexes

services/ollama_client/ollama/
└── chat.go                     # Go ChatClient for Ollama /api/chat
```

## Start / Stop

### Start Scout Server

```bash
cd /home/scout/projects/workers
./scout/start_scout.sh
```

This seeds the baseline from `~/projects/simplesieve/`, initializes worker git repos, creates `tier.json` and `leaderboard.json`, builds `scout.go` if needed, then starts the server on port 8080.

### Manual Start (if already initialized)

```bash
cd /home/scout/projects/workers/scout
nohup ./bin/scout > scout.log 2>&1 &
echo $! > scout.pid
```

### Stop

```bash
kill $(cat /home/scout/projects/workers/scout/scout.pid) 2>/dev/null
# or
pkill -f "scout/bin/scout"
```

### Verify

```bash
curl http://localhost:8080/health
# → {"status":"ok","service":"scout-cgi-mcp","version":"1.0.0"}
```

## Problem Tiers

| Tier | Limit | Primes | KAT Hash (SHA-256) |
|------|-------|--------|---------------------|
| min | 100 | 25 | `258e13d8...` |
| ci_smoke | 1000 | 168 | `55542ac8...` |
| dev | 100000 | 9592 | `448c035b...` |

Workers start at `min` and advance to harder tiers by winning matches.

## MCP Tools

The Scout server exposes tools via two mechanisms:

### Arena Tools (for LLM worker agents in `run_match.sh`)

These six tools are presented to each Ollama agent as OpenAI-compatible function definitions:

| Tool | Description |
|------|-------------|
| `read_file(path)` | Read a source file (`internal/sieve/sieve.go`, `main.go`, `go.mod`) |
| `write_file(path, content)` | Write/modify a source file |
| `compile()` | `go build` the sandbox; returns errors or success |
| `run(limit)` | Execute the compiled sieve; returns KAT hash, duration, memory, prime count |
| `submit_for_match()` | Git-commit the current code as the match entry |
| `get_leaderboard()` | Return current standings |

### Full MCP Tool Registry (via `mcp/tools/list.sh`)

All tools accessible via `POST /cgi-bin/mcp/tools/call.sh`:

- **worker1.*** / **worker2.*** / **baseline.*** — compile, run, verify, config for each worker binary
- **kat_verify.verify** — verify a KAT hash against the manifest
- **manifest.get** — return `A000040.json` manifest
- **judge.heuristic** — heuristic judge for worker results
- **arena.get_context** — baseline code, tier info, leaderboard
- **arena.read_file** / **arena.write_file** — sandbox file access by worker_id
- **arena.submit** — git-commit and return diff stats
- **arena.leaderboard** / **arena.status** / **arena.match_result** — state queries
- **arena.run_match** — orchestrate a full match (workers, Ollama hosts, model)

## How Models Use Tools

1. **Tool registration**: `run_match.sh` sends an Ollama `/api/chat` request with `tools` parameter containing the 6 agent tools as OpenAI function definitions.

2. **Agent loop**: The model responds with either:
   - **Text content** → treated as final response, loop ends
   - **Tool call** → `run_match.sh` executes the tool via `execute_tool()`, appends result as a `"role":"tool"` message, and continues the conversation

3. **Tool dispatch**: `execute_tool()` maps tool names to CGI scripts:
   - `read_file` → `read_file.sh` (reads sandbox file via stdin JSON)
   - `write_file` → `write_file.sh` (writes sandbox file)
   - `compile` → runs `go build` in worker sandbox directory
   - `run` → executes compiled binary with `-limit` flag, captures stdout (KAT hash) and stderr (JSON metrics)
   - `submit_for_match` → `submit.sh` (git-commit, return diff stats)
   - `get_leaderboard` → `leaderboard.sh`

4. **Max turns**: The agent gets 30 tool-calling turns per match. After submission or max turns, the loop ends and scoring begins.

5. **External clients** (non-arena): Call `POST /cgi-bin/mcp/tools/call.sh` with `{"name":"<tool_name>","arguments":{...}}` and receive JSON responses. Sessions are tracked via `scout_session` cookie.

## Scoring

Each worker is scored algorithmically (no LLM judge):

| Component | Max | How |
|-----------|-----|-----|
| Originality | 20 | Git diff lines vs baseline: ≥50→20, ≥20→15, ≥10→10, ≥5→5 |
| Correctness | 20 | KAT hash matches baseline hash |
| Speed | 40 | `baseline_duration / worker_duration × 40` |
| Memory | 20 | `baseline_memory / worker_memory × 20` |
| **Total** | **100** | Sum of all components |

Higher score wins. Ties are recorded but no loss assigned.

## Baseline Sieve

The reference implementation is a self-contained Go module (`module simplesieve`) with:

- `main.go`: CLI wrapper with `-limit` and `-hash` flags; outputs KAT hash to stdout and JSON metrics to stderr
- `internal/sieve/sieve.go`: Bit-packed segmented Sieve of Eratosthenes with wheel-210 factorization

Workers edit only `internal/sieve/sieve.go`; `main.go` is a stable wrapper.

## Prerequisites

- Go 1.21+
- Ollama on two hosts (`worker1:11434`, `worker2:11434`) or localhost fallback
- A tool-capable model (e.g., `qwen2.5:0.5b`): `ollama pull qwen2.5:0.5b` on each worker host
- `jq` and `bc` for JSON and arithmetic in CGI scripts

## Running a Match

```bash
curl -X POST http://localhost:8080/cgi-bin/mcp/tools/call.sh \
  -d '{"name":"arena.run_match","arguments":{}}'
```

With custom hosts and model:
```bash
curl -X POST http://localhost:8080/cgi-bin/mcp/tools/call.sh \
  -d '{"name":"arena.run_match","arguments":{"worker1_host":"192.168.1.10:11434","worker2_host":"192.168.1.11:11434","model":"qwen2.5:7b"}}'
```

## API Endpoints

| Route | Description |
|-------|-------------|
| `GET /health` | Health check |
| `GET /status` | Server status, sessions, workers |
| `GET /events` | Server-Sent Events stream |
| `POST /cgi-bin/<path>` | Execute CGI tool script |
