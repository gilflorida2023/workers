#!/bin/bash
set -euo pipefail

SCOUT_DIR="/home/scout/projects/workers/scout"
BIN_DIR="$SCOUT_DIR/bin"
CGI_DIR="$SCOUT_DIR/cgi-bin"

echo "=== Starting Scout CGI MCP Server ==="

for bin in w1_baseline w2_wheel2310 w3_seq_cacheopt kat_verify judge compile execute ollama_client; do
    if [[ ! -x "$BIN_DIR/$bin" ]]; then
        echo "WARNING: $BIN_DIR/$bin not found or not executable"
    fi
done

find "$CGI_DIR" -name "*.sh" -exec chmod +x {} \;

for ctx in baseline judge worker1 worker2; do
    CTX_DIR="$SCOUT_DIR/contexts/$ctx"
    if [[ ! -d "$CTX_DIR/.git" ]]; then
        echo "Initializing git repo for $ctx context..."
        cd "$CTX_DIR"
        git init -q
        echo '[]' > mutations.jsonl
        git add mutations.jsonl
        git config user.email "scout@local"
        git config user.name "Scout Bot"
        git commit -q -m "init: $ctx context"
    fi
done

touch "$SCOUT_DIR/locks/judge.lock"
touch "$SCOUT_DIR/locks/match.lock"

# ─── Initialize Arena ──────────────────────────────────────────
ARENA_DIR="$SCOUT_DIR/contexts/arena"
if [[ ! -d "$ARENA_DIR/baseline/.git" ]]; then
    echo "Initializing arena..."

    mkdir -p "$ARENA_DIR/baseline" "$ARENA_DIR/worker1" "$ARENA_DIR/worker2"

    # Seed baseline from simplesieve
    if [[ ! -f "$ARENA_DIR/baseline/main.go" ]]; then
        SIMPLE_DIR="/home/scout/projects/simplesieve"
        if [[ -f "$SIMPLE_DIR/main.go" ]]; then
            mkdir -p "$ARENA_DIR/baseline/internal/sieve"
            cp "$SIMPLE_DIR/main.go" "$ARENA_DIR/baseline/main.go"
            cp "$SIMPLE_DIR/go.mod" "$ARENA_DIR/baseline/go.mod"
            cp "$SIMPLE_DIR/internal/sieve/sieve.go" "$ARENA_DIR/baseline/internal/sieve/sieve.go"
            echo "Baseline seeded from simplesieve"
        else
            echo "ERROR: simplesieve not found at $SIMPLE_DIR"
            exit 1
        fi
    fi

    # Init baseline git
    cd "$ARENA_DIR/baseline"
    git init -q
    git config user.email "arena@local"
    git config user.name "Arena Baseline"
    git add -A 2>/dev/null || true
    git commit -q -m "init: baseline sieve algorithm" 2>/dev/null || true

    # Init worker git repos
    for w in worker1 worker2; do
        cd "$ARENA_DIR/$w"
        git init -q
        git config user.email "$w@arena.local"
        git config user.name "Worker $w"
    done

    # Create tier.json
    cat > "$ARENA_DIR/tier.json" << 'TIER'
{"tier":"min","limit":100}
TIER

    # Initialize leaderboard
    if [[ ! -f "$SCOUT_DIR/leaderboard.json" ]]; then
        echo '{"workers":[],"matches":[]}' > "$SCOUT_DIR/leaderboard.json"
    fi

    touch "$ARENA_DIR/matches.jsonl"
    touch "$ARENA_DIR/mutations.jsonl"

    echo "Arena initialized"
fi

if [[ ! -x "$BIN_DIR/scout" ]] || [[ "$SCOUT_DIR/scout.go" -nt "$BIN_DIR/scout" ]]; then
    echo "Building scout.go..."
    cd "$SCOUT_DIR"
    go build -o "$BIN_DIR/scout" scout.go
fi

echo "Starting Scout on :8080..."
exec "$BIN_DIR/scout"
