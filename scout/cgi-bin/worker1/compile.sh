#!/bin/bash
set -euo pipefail

INPUT=$(cat)
LIMIT=$(echo "$INPUT" | jq -r '.limit // 100')
WORKER_BIN="${SCOUT_BIN_DIR}/w2_wheel2310"

if [[ ! -x "$WORKER_BIN" ]]; then
    echo '{"success":false,"error":"worker binary not found: w2_wheel2310","retryable":false}'
    exit 1
fi

"$WORKER_BIN" -limit "$LIMIT" -config 2>&1
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    echo '{"success":false,"error":"compile failed","retryable":true}'
    exit 1
fi

echo '{"success":true,"worker":"w2_wheel2310","limit":'"$LIMIT"'}'