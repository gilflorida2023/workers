#!/bin/bash
# workspace/write.sh - Write file to workspace

WORKSPACE_ROOT="/home/scout/projects/sandbox/workspace"
INPUT=$(cat)

PATH_PARAM=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
CONTENT=$(echo "$INPUT" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g')

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

# Create parent directories
mkdir -p "$(dirname "$FULL_PATH")"

# Write file
echo -n "$CONTENT" > "$FULL_PATH"
BYTES=$(stat -c%s "$FULL_PATH" 2>/dev/null || echo 0)

echo "{\"success\":true,\"path\":\"$PATH_PARAM\",\"bytes_written\":$BYTES}"