#!/bin/bash
set -euo pipefail

INPUT=$(cat)
WORKER_ID=$(echo "$INPUT" | jq -r '.worker_id // ""' | tr -d '\n')
FILE_PATH=$(echo "$INPUT" | jq -r '.path // ""' | tr -d '\n')
CONTENT=$(echo "$INPUT" | jq -r '.content // ""')

if [[ -z "$WORKER_ID" || -z "$FILE_PATH" ]]; then
    echo '{"success":false,"error":"worker_id and path required"}'
    exit 1
fi

WORKER_DIR="/home/scout/projects/workers/scout/contexts/arena/$WORKER_ID"
mkdir -p "$WORKER_DIR"

REAL_PATH=$(realpath -m "$WORKER_DIR/$FILE_PATH" 2>/dev/null || echo "")
WORKER_DIR_REAL=$(realpath "$WORKER_DIR" 2>/dev/null || echo "")

if [[ -z "$REAL_PATH" || "$REAL_PATH" != "$WORKER_DIR_REAL"* ]]; then
    echo '{"success":false,"error":"invalid path: must be within worker sandbox"}'
    exit 1
fi

mkdir -p "$(dirname "$REAL_PATH")"
printf '%s' "$CONTENT" > "$REAL_PATH"

SIZE=$(wc -c < "$REAL_PATH")
echo "{\"success\":true,\"path\":$(echo "$FILE_PATH" | jq -Rs .),\"bytes_written\":$SIZE}"
