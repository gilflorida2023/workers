#!/bin/bash
set -euo pipefail

MANIFEST_PATH="${SCOUT_MANIFEST_DIR}/A000040.json"

if [[ ! -f "$MANIFEST_PATH" ]]; then
    echo '{"success":false,"error":"manifest not found","retryable":false}'
    exit 1
fi

cat "$MANIFEST_PATH"