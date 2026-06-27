#!/bin/bash
set -euo pipefail

INPUT=$(cat)
WORKER_ID=$(echo "$INPUT" | jq -r '.worker_id // ""' | tr -d '\n')

if [[ -z "$WORKER_ID" ]]; then
    echo '{"success":false,"error":"worker_id required"}'
    exit 1
fi

MATCHES_FILE="/home/scout/projects/workers/scout/contexts/arena/matches.jsonl"

if [[ ! -f "$MATCHES_FILE" ]]; then
    echo '{"success":true,"has_match":false,"worker_id":'"$(printf '%s' "$WORKER_ID" | jq -Rs .)"'}'
    exit 0
fi

LAST_MATCH="null"
while IFS= read -r line; do
    if echo "$line" | jq -e --arg w "$WORKER_ID" '(.worker_a == $w) or (.worker_b == $w)' >/dev/null 2>&1; then
        LAST_MATCH=$line
    fi
done < "$MATCHES_FILE"

if [[ "$LAST_MATCH" == "null" ]]; then
    echo '{"success":true,"has_match":false,"worker_id":'"$(printf '%s' "$WORKER_ID" | jq -Rs .)"'}'
    exit 0
fi

echo "{\"success\":true,\"has_match\":true,\"worker_id\":$(printf '%s' "$WORKER_ID" | jq -Rs .),\"match\":$LAST_MATCH}"
