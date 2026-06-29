#!/bin/bash
# workspace/delete.sh - Delete file or directory from workspace

WORKSPACE_ROOT="/home/scout/projects/sandbox/workspace"
INPUT=$(cat)

PATH_PARAM=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
RECURSIVE=$(echo "$INPUT" | grep -o '"recursive"[[:space:]]*:[[:space:]]*true' && echo true || echo false)

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

if [[ ! -e "$FULL_PATH" ]]; then
    echo '{"success":false,"error":"Path not found"}'
    exit 1
fi

if [[ -d "$FULL_PATH" && "$RECURSIVE" != "true" ]]; then
    echo '{"success":false,"error":"Directory requires recursive=true"}'
    exit 1
fi

rm -rf "$FULL_PATH"

echo "{\"success\":true,\"path\":\"$PATH_PARAM\"}"