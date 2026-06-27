#!/bin/bash
set -euo pipefail

INPUT=$(cat)
WORKER_ID=$(echo "$INPUT" | jq -r '.worker_id // ""' | tr -d '\n')

if [[ -z "$WORKER_ID" ]]; then
    echo '{"success":false,"error":"worker_id required"}'
    exit 1
fi

WORKER_DIR="/home/scout/projects/workers/scout/contexts/arena/$WORKER_ID"
mkdir -p "$WORKER_DIR"

if [[ ! -d "$WORKER_DIR/.git" ]]; then
    git -C "$WORKER_DIR" init -q
    git -C "$WORKER_DIR" config user.email "worker@arena.local"
    git -C "$WORKER_DIR" config user.name "Worker $WORKER_ID"
fi

git -C "$WORKER_DIR" add -A
if git -C "$WORKER_DIR" diff --cached --quiet; then
    echo '{"success":false,"error":"no changes to submit; write_file first"}'
    exit 1
fi

git -C "$WORKER_DIR" commit -q -m "submission $(date -u +%Y%m%dT%H%M%SZ)"

DIFF_STATS=$(git -C "$WORKER_DIR" diff HEAD~1 --stat 2>/dev/null || echo "")
DIFF_LINES=$(git -C "$WORKER_DIR" diff HEAD~1 2>/dev/null | wc -l || echo 0)
FILES_CHANGED=$(git -C "$WORKER_DIR" diff HEAD~1 --stat 2>/dev/null | tail -1 | grep -oP '\d+ file' | grep -oP '\d+' || echo 0)

echo "{\"success\":true,\"worker_id\":$(printf '%s' "$WORKER_ID" | jq -Rs .),\"diff_lines\":$DIFF_LINES,\"files_changed\":$FILES_CHANGED,\"submitted_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
