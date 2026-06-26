#!/bin/bash
set -euo pipefail

WORKER_BIN="${SCOUT_BIN_DIR}/w2_wheel2310"

if [[ ! -x "$WORKER_BIN" ]]; then
    echo '{"success":false,"error":"worker binary not found: w2_wheel2310","retryable":false}'
    exit 1
fi

echo '{"success":true,"worker":"w2_wheel2310","algorithm":"wheel-2310-parallel","description":"Bit-packed segmented sieve with wheel factorization (2,3,5,7,11) - parallel implementation"}'