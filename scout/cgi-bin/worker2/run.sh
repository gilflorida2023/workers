#!/bin/bash
set -euo pipefail

INPUT=$(cat)
LIMIT=$(echo "$INPUT" | jq -r '.limit // 100')
WORKER_BIN="${SCOUT_BIN_DIR}/w3_seq_cacheopt"

if [[ ! -x "$WORKER_BIN" ]]; then
    echo '{"success":false,"error":"worker binary not found: w3_seq_cacheopt","retryable":false}'
    exit 1
fi

OUTPUT=$("$WORKER_BIN" -limit "$LIMIT" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    ERR=$(echo "$OUTPUT" | head -1 | sed 's/"/\\"/g')
    echo '{"success":false,"error":"run failed: '"$ERR"'","retryable":true}'
    exit 1
fi

echo "$OUTPUT"