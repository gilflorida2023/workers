#!/bin/bash
set -euo pipefail

WORKER_BIN="${SCOUT_BIN_DIR}/w3_seq_cacheopt"

if [[ ! -x "$WORKER_BIN" ]]; then
    echo '{"success":false,"error":"worker binary not found: w3_seq_cacheopt","retryable":false}'
    exit 1
fi

echo '{"success":true,"worker":"w3_seq_cacheopt","algorithm":"wheel-2310-sequential","description":"Bit-packed segmented sieve with wheel factorization (2,3,5,7,11) - sequential cache-optimized implementation"}'