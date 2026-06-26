#!/bin/bash
set -euo pipefail

INPUT=$(cat)
LOCK_FILE="/home/scout/projects/workers/scout/locks/judge.lock"

exec 200>"$LOCK_FILE"
flock -x 200

SCOUT_CONTEXTS_DIR="/home/scout/projects/workers/scout/contexts"
ENTITY=$(echo "$INPUT" | jq -r '.entity // "default"')
WORKER_RESULTS=$(echo "$INPUT" | jq -c '.worker_results // []')
CONTEXT_DIR="$SCOUT_CONTEXTS_DIR/$ENTITY"
MUTATIONS_FILE="$CONTEXT_DIR/mutations.jsonl"

mkdir -p "$CONTEXT_DIR"
if [[ ! -d "$CONTEXT_DIR/.git" ]]; then
    git -C "$CONTEXT_DIR" init -q
    git -C "$CONTEXT_DIR" config user.email "scout@local"
    git -C "$CONTEXT_DIR" config user.name "Scout Judge"
fi

RANKED=$(echo "$WORKER_RESULTS" | jq -c 'map(. + {score: ((.duration_ms // 999999) * 1000000 + (.peak_mem_mb // 999999) * 1000 - (.primes // 0))}) | sort_by(.score)')

VERDICT=$(echo "$RANKED" | jq -c --arg entity "$ENTITY" '{
    timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    entity: $entity,
    winner: (.[0].worker // ""),
    ranking: map(.worker),
    details: .
}')

echo "$VERDICT" >> "$MUTATIONS_FILE"
git -C "$CONTEXT_DIR" add mutations.jsonl
git -C "$CONTEXT_DIR" commit -q -m "judge: $ENTITY verdict $(date -u +%Y%m%dT%H%M%SZ)"

echo "$VERDICT"

flock -u 200
