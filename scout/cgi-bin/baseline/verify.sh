#!/bin/bash
set -euo pipefail

INPUT=$(cat)
LIMIT=$(echo "$INPUT" | jq -r '.limit // 100')
WORKER_BIN="${SCOUT_BIN_DIR}/w1_baseline"
KAT_VERIFY="${SCOUT_BIN_DIR}/kat_verify"

if [[ ! -x "$WORKER_BIN" ]] || [[ ! -x "$KAT_VERIFY" ]]; then
    echo '{"success":false,"error":"worker or kat_verify binary not found","retryable":false}'
    exit 1
fi

# Map count to upper limit for known verification tiers
case "$LIMIT" in
    100) ACTUAL_LIMIT=541 ;;
    1000) ACTUAL_LIMIT=7919 ;;
    100000) ACTUAL_LIMIT=1299709 ;;
    *) ACTUAL_LIMIT=$LIMIT ;;
esac

# Run worker to get hash and result JSON separately
HASH=$("$WORKER_BIN" -limit "$ACTUAL_LIMIT" -hash 2>/dev/null)
HASH_EXIT=$?
RESULT_JSON=$("$WORKER_BIN" -limit "$ACTUAL_LIMIT" 2>&1 >/dev/null)
RESULT_EXIT=$?

if [[ $HASH_EXIT -ne 0 ]] || [[ $RESULT_EXIT -ne 0 ]]; then
    ERR=$(echo "$HASH" | head -1 | sed 's/"/\\"/g')
    echo '{"success":false,"error":"worker failed: '"$ERR"'","retryable":true}'
    exit 1
fi

KAT_HASH=$(echo "$HASH" | tail -1)

# Extract prime count from result JSON
PRIME_COUNT=$(echo "$RESULT_JSON" | jq -r '.primes // 0')

# Verify with kat_verify using prime count
VERIFY_OUTPUT=$("$KAT_VERIFY" "$PRIME_COUNT" "$KAT_HASH" "$SCOUT_MANIFEST_DIR/A000040.json" 2>&1)
VERIFY_EXIT=$?

if [[ $VERIFY_EXIT -ne 0 ]]; then
    ERR=$(echo "$VERIFY_OUTPUT" | head -1 | sed 's/"/\\"/g')
    echo '{"success":false,"error":"KAT verification failed: '"$ERR"'","retryable":false}'
    exit 1
fi

echo '{"success":true,"worker":"w1_baseline","limit":'"$LIMIT"',"actual_limit":'"$ACTUAL_LIMIT"',"prime_count":'"$PRIME_COUNT"',"kat_hash":"'"$KAT_HASH"'"}'