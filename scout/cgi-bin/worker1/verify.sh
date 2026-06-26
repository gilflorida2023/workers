#!/bin/bash
set -euo pipefail

echo "DEBUG: verify.sh started" >&2
INPUT=$(cat)
echo "DEBUG: INPUT=$INPUT" >&2
LIMIT=$(echo "$INPUT" | jq -r '.limit // 100')
echo "DEBUG: LIMIT=$LIMIT" >&2
WORKER_BIN="${SCOUT_BIN_DIR}/w2_wheel2310"
KAT_VERIFY="${SCOUT_BIN_DIR}/kat_verify"
echo "DEBUG: WORKER_BIN=$WORKER_BIN" >&2
echo "DEBUG: KAT_VERIFY=$KAT_VERIFY" >&2

if [[ ! -x "$WORKER_BIN" ]] || [[ ! -x "$KAT_VERIFY" ]]; then
    echo '{"success":false,"error":"worker or kat_verify binary not found","retryable":false}'
    exit 1
fi

echo "DEBUG: binaries found" >&2
echo "DEBUG: SCOUT_BIN_DIR=$SCOUT_BIN_DIR" >&2
echo "DEBUG: SCOUT_MANIFEST_DIR=$SCOUT_MANIFEST_DIR" >&2

# Map count to upper limit for known verification tiers
case "$LIMIT" in
    100) ACTUAL_LIMIT=541 ;;
    1000) ACTUAL_LIMIT=7919 ;;
    100000) ACTUAL_LIMIT=1299709 ;;
    *) ACTUAL_LIMIT=$LIMIT ;;
esac

# Run worker to get hash and result JSON
OUTPUT=$("$WORKER_BIN" -limit "$ACTUAL_LIMIT" -hash 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    ERR=$(echo "$OUTPUT" | head -1 | sed 's/"/\\"/g')
    echo '{"success":false,"error":"worker failed: '"$ERR"'","retryable":true}'
    exit 1
fi

# Extract KAT hash (last line) and result JSON (all but last line)
KAT_HASH=$(echo "$OUTPUT" | tail -1)
RESULT_JSON=$(echo "$OUTPUT" | head -n -1)

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

echo '{"success":true,"worker":"w2_wheel2310","limit":'"$LIMIT"',"actual_limit":'"$ACTUAL_LIMIT"',"prime_count":'"$PRIME_COUNT"',"kat_hash":"'"$KAT_HASH"'"}'