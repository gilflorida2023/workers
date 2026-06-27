#!/bin/bash
set -euo pipefail

INPUT=$(cat)
WORKER_ID=$(echo "$INPUT" | jq -r '.worker_id // ""' | tr -d '\n')
TIER_FILE="/home/scout/projects/workers/scout/contexts/arena/tier.json"

if [[ ! -f "$TIER_FILE" ]]; then
    echo '{"success":false,"error":"tier.json not found; arena not initialized"}'
    exit 1
fi

TIER=$(cat "$TIER_FILE" | tr -d '\n')
LIMIT=$(echo "$TIER" | jq -r '.limit // 100')
TIER_NAME=$(echo "$TIER" | jq -r '.tier // "min"')

BASELINE_DIR="/home/scout/projects/workers/scout/contexts/arena/baseline"

MAIN_CODE=""
SIEVE_CODE=""
GOMOD_CODE=""

if [[ -f "$BASELINE_DIR/main.go" ]]; then
    MAIN_CODE=$(cat "$BASELINE_DIR/main.go" | jq -Rs .)
fi
if [[ -f "$BASELINE_DIR/internal/sieve/sieve.go" ]]; then
    SIEVE_CODE=$(cat "$BASELINE_DIR/internal/sieve/sieve.go" | jq -Rs .)
fi
if [[ -f "$BASELINE_DIR/go.mod" ]]; then
    GOMOD_CODE=$(cat "$BASELINE_DIR/go.mod" | jq -Rs .)
fi

WORKER_DIR="/home/scout/projects/workers/scout/contexts/arena/$WORKER_ID"
WORKER_SUBMITTED=false
WORKER_SCORE=0
if [[ -f "$WORKER_DIR/.submit_score" ]]; then
    WORKER_SUBMITTED=true
    WORKER_SCORE=$(cat "$WORKER_DIR/.submit_score")
fi

LEADERBOARD_DATA="[]"
LEADERBOARD_FILE="/home/scout/projects/workers/scout/leaderboard.json"
if [[ -f "$LEADERBOARD_FILE" ]]; then
    LEADERBOARD_DATA=$(cat "$LEADERBOARD_FILE")
fi

PREV_WINNER=""
MATCHES_FILE="/home/scout/projects/workers/scout/contexts/arena/matches.jsonl"
if [[ -f "$MATCHES_FILE" ]]; then
    PREV_WINNER=$(tail -1 "$MATCHES_FILE" 2>/dev/null | jq -r '.winner // ""' 2>/dev/null | tr -d '\n' || echo "")
fi

cat <<EOF
{
  "success": true,
  "worker_id": $(echo -n "$WORKER_ID" | jq -Rs .),
  "tier": $(printf '%s' "$TIER_NAME" | jq -Rs .),
  "limit": $LIMIT,
  "baseline": {
    "main.go": $MAIN_CODE,
    "internal/sieve/sieve.go": $SIEVE_CODE,
    "go.mod": $GOMOD_CODE,
    "description": "Bit-packed segmented Sieve of Eratosthenes with wheel factorization. Edit internal/sieve/sieve.go to improve the algorithm."
  },
  "worker_submitted": $WORKER_SUBMITTED,
  "worker_last_score": $WORKER_SCORE,
  "previous_winner": $(printf '%s' "$PREV_WINNER" | jq -Rs .),
  "leaderboard": $LEADERBOARD_DATA
}
EOF
