#!/bin/bash
set -euo pipefail

WORKER_BIN="${SCOUT_BIN_DIR}/w1_baseline"

if [[ ! -x "$WORKER_BIN" ]]; then
    echo '{"success":false,"error":"worker binary not found: w1_baseline","retryable":false}'
    exit 1
fi

echo '{"success":true,"worker":"w1_baseline","algorithm":"wheel-210-parallel","description":"Bit-packed segmented sieve with wheel factorization (2,3,5,7) - parallel baseline implementation"}'