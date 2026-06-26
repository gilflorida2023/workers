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

if [[ ! -x "$BIN_DIR/scout" ]] || [[ "$SCOUT_DIR/scout.go" -nt "$BIN_DIR/scout" ]]; then
    echo "Building scout.go..."
    cd "$SCOUT_DIR"
    go build -o "$BIN_DIR/scout" scout.go
fi

echo "Starting Scout on :8080..."
exec "$BIN_DIR/scout"