#!/bin/bash
set -euo pipefail

INPUT=$(cat)
WORKER_ID=$(echo "$INPUT" | jq -r '.worker_id // ""' | tr -d '\n')

if [[ -z "$WORKER_ID" ]]; then
    echo '{"success":false,"error":"worker_id required"}'
    exit 1
fi

WORKER_DIR="/home/scout/projects/workers/scout/contexts/arena/$WORKER_ID"
TIER_FILE="/home/scout/projects/workers/scout/contexts/arena/tier.json"

SUBMITTED=false
COMMITS=0
LAST_COMMIT=""
SCORE=0

if [[ -d "$WORKER_DIR/.git" ]]; then
    COMMITS=$(git -C "$WORKER_DIR" rev-list --count HEAD 2>/dev/null || echo 0)
    LAST_COMMIT=$(git -C "$WORKER_DIR" log -1 --format="%H %ai" 2>/dev/null || echo "")
fi
if [[ -f "$WORKER_DIR/.submit_score" ]]; then
    SUBMITTED=true
    SCORE=$(cat "$WORKER_DIR/.submit_score")
fi

CURRENT_TIER="min"
CURRENT_LIMIT=541
if [[ -f "$TIER_FILE" ]]; then
CURRENT_TIER=$(cat "$TIER_FILE" | tr -d '\n' | jq -r '.tier // "min"')
CURRENT_LIMIT=$(cat "$TIER_FILE" | tr -d '\n' | jq -r '.limit // 541')
fi

# Get match history for this worker
MATCHES_FILE="/home/scout/projects/workers/scout/contexts/arena/matches.jsonl"
WINS=0
LOSSES=0
MATCHES_PLAYED=0
if [[ -f "$MATCHES_FILE" ]]; then
    while IFS= read -r line; do
        if echo "$line" | jq -e --arg w "$WORKER_ID" '.winner == $w' >/dev/null 2>&1; then
            WINS=$((WINS + 1))
            MATCHES_PLAYED=$((MATCHES_PLAYED + 1))
        elif echo "$line" | jq -e --arg w "$WORKER_ID" '(.worker_a == $w) or (.worker_b == $w)' >/dev/null 2>&1; then
            LOSSES=$((LOSSES + 1))
            MATCHES_PLAYED=$((MATCHES_PLAYED + 1))
        fi
    done < "$MATCHES_FILE"
fi

echo "{\"success\":true,\"worker_id\":$(printf '%s' "$WORKER_ID" | jq -Rs .),\"submitted\":$SUBMITTED,\"score\":$SCORE,\"commits\":$COMMITS,\"last_commit\":$(printf '%s' "$LAST_COMMIT" | jq -Rs .),\"current_tier\":$(printf '%s' "$CURRENT_TIER" | jq -Rs .),\"current_limit\":$CURRENT_LIMIT,\"matches_played\":$MATCHES_PLAYED,\"wins\":$WINS,\"losses\":$LOSSES}"
