#!/bin/bash
set -euo pipefail

INPUT=$(cat)
WORKER_ID=$(echo "$INPUT" | jq -r '.worker_id // ""' | tr -d '\n')
FILE_PATH=$(echo "$INPUT" | jq -r '.path // ""' | tr -d '\n')

if [[ -z "$WORKER_ID" || -z "$FILE_PATH" ]]; then
    echo '{"success":false,"error":"worker_id and path required"}'
    exit 1
fi

# Safety: only allow files in the worker's sandbox
WORKER_DIR="/home/scout/projects/workers/scout/contexts/arena/$WORKER_ID"
REAL_PATH=$(realpath "$WORKER_DIR/$FILE_PATH" 2>/dev/null || echo "")
WORKER_DIR_REAL=$(realpath "$WORKER_DIR" 2>/dev/null || echo "")

if [[ -z "$REAL_PATH" || "$REAL_PATH" != "$WORKER_DIR_REAL"* ]]; then
    echo '{"success":false,"error":"invalid path: must be within worker sandbox"}'
    exit 1
fi

if [[ ! -f "$REAL_PATH" ]]; then
    echo '{"success":false,"error":"file not found: '"$FILE_PATH"'"}'
    exit 1
fi

CONTENT=$(cat "$REAL_PATH" | jq -Rs .)
echo "{\"success\":true,\"path\":$(echo "$FILE_PATH" | jq -Rs .),\"content\":$CONTENT}"
