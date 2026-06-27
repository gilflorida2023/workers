#!/bin/bash
set -euo pipefail

LEADERBOARD_FILE="/home/scout/projects/workers/scout/leaderboard.json"

if [[ ! -f "$LEADERBOARD_FILE" ]]; then
    echo '{"success":true,"leaderboard":[],"total_matches":0}'
    exit 0
fi

LEADERBOARD=$(cat "$LEADERBOARD_FILE")
TOTAL_MATCHES=$(echo "$LEADERBOARD" | jq '[.matches[]] | length' 2>/dev/null || echo 0)

echo "{\"success\":true,\"leaderboard\":$LEADERBOARD,\"total_matches\":$TOTAL_MATCHES}"
