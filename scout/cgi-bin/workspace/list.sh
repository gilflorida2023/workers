#!/bin/bash
# workspace/list.sh - List files in workspace

WORKSPACE_ROOT="/home/scout/projects/sandbox/workspace"
INPUT=$(cat)

PATH_PARAM=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
PATH_PARAM=${PATH_PARAM:-.}

FULL_PATH="${WORKSPACE_ROOT}/${PATH_PARAM}"
FULL_PATH=$(realpath "$FULL_PATH" 2>/dev/null || echo "")

if [[ ! "$FULL_PATH" =~ ^"$WORKSPACE_ROOT" ]]; then
    echo '{"success":false,"error":"Path outside workspace"}'
    exit 1
fi

if [[ ! -d "$FULL_PATH" ]]; then
    if [[ -f "$FULL_PATH" ]]; then
        echo "{\"success\":false,\"error\":\"Not a directory: $PATH_PARAM\",\"suggestion\":\"Use workspace.read to read files, or use workspace.list on a parent directory.\"}"
    else
        echo "{\"success\":false,\"error\":\"Directory not found: $PATH_PARAM\",\"suggestion\":\"List the parent directory first with workspace.list path='.' to discover correct paths.\"}"
    fi
    exit 1
fi

cd "$WORKSPACE_ROOT"

echo '{"success":true,"path":"'"$PATH_PARAM"'","files":['
FIRST=true
while IFS= read -r -d '' entry; do
    NAME=$(basename "$entry")
    if [[ -d "$entry" ]]; then
        TYPE="directory"
        SIZE=0
    else
        TYPE="file"
        SIZE=$(stat -c%s "$entry" 2>/dev/null || echo 0)
    fi
    MODIFIED=$(stat -c'%Y' "$entry" 2>/dev/null | xargs -I{} date -u -d @{} +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
    
    if [[ "$FIRST" == true ]]; then
        FIRST=false
    else
        echo ","
    fi
    echo -n "{\"name\":\"$NAME\",\"type\":\"$TYPE\",\"size\":$SIZE,\"modified\":\"$MODIFIED\"}"
done < <(find "$PATH_PARAM" -maxdepth 1 -mindepth 1 -print0 2>/dev/null | sort -z)
echo ']}'