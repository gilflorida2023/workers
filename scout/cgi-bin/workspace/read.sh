#!/bin/bash
# workspace/read.sh - Read file from workspace

WORKSPACE_ROOT="/home/scout/projects/sandbox/workspace"
INPUT=$(cat)

PATH_PARAM=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [[ -z "$PATH_PARAM" ]]; then
    echo '{"success":false,"error":"Missing path parameter"}'
    exit 1
fi

FULL_PATH="${WORKSPACE_ROOT}/${PATH_PARAM}"
FULL_PATH=$(realpath "$FULL_PATH" 2>/dev/null || echo "")

if [[ ! "$FULL_PATH" =~ ^"$WORKSPACE_ROOT" ]]; then
    echo '{"success":false,"error":"Path outside workspace"}'
    exit 1
fi

if [[ ! -f "$FULL_PATH" ]]; then
    echo "{\"success\":false,\"error\":\"File not found: $PATH_PARAM\",\"suggestion\":\"Use workspace.list to find the correct file path, then use the EXACT name from list output.\"}"
    exit 1
fi

CONTENT=$(cat "$FULL_PATH")
SIZE=$(stat -c%s "$FULL_PATH" 2>/dev/null || echo 0)

# Escape for JSON
ESCAPED_CONTENT=$(echo "$CONTENT" | sed 's/\\/\\\\/g; s/\t/\\t/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n')

echo "{\"success\":true,\"path\":\"$PATH_PARAM\",\"content\":\"$ESCAPED_CONTENT\",\"size\":$SIZE}"