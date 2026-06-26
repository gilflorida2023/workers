#!/bin/bash
set -euo pipefail

INPUT=$(cat)
LIMIT=$(echo "$INPUT" | jq -r '.limit // 100')
KAT_HASH=$(echo "$INPUT" | jq -r '.kat_hash // ""')
KAT_VERIFY="${SCOUT_BIN_DIR}/kat_verify"

if [[ ! -x "$KAT_VERIFY" ]]; then
    echo '{"success":false,"error":"kat_verify binary not found","retryable":false}'
    exit 1
fi

if [[ -z "$KAT_HASH" ]]; then
    echo '{"success":false,"error":"kat_hash required","retryable":false}'
    exit 1
fi

OUTPUT=$("$KAT_VERIFY" "$LIMIT" "$KAT_HASH" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    ERR=$(echo "$OUTPUT" | head -1 | sed 's/"/\\"/g')
    echo '{"success":false,"error":"KAT verification failed: '"$ERR"'","retryable":false}'
    exit 1
fi

echo '{"success":true,"verified":true,"limit":'"$LIMIT"',"kat_hash":"'"$KAT_HASH"'"}'