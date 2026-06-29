#!/bin/bash
# workspace/run.sh - Run executable in workspace

WORKSPACE_ROOT="/home/scout/projects/sandbox/workspace"
INPUT=$(cat)

PATH_PARAM=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
ARGS_JSON=$(echo "$INPUT" | grep -o '"args"[[:space:]]*:[[:space:]]*\[[^]]*\]' | sed 's/.*"args"[[:space:]]*:[[:space:]]*//')
TIMEOUT=$(echo "$INPUT" | grep -o '"timeout"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*"timeout"[[:space:]]*:[[:space:]]*//')
TIMEOUT=${TIMEOUT:-30}

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

if [[ ! -f "$FULL_PATH" && ! -x "$FULL_PATH" ]]; then
    # Try with workspace root prefix for commands like "python3 script.py"
    FULL_PATH_CMD="$WORKSPACE_ROOT/$PATH_PARAM"
    if [[ ! -f "$FULL_PATH_CMD" && ! -x "$FULL_PATH_CMD" ]]; then
        echo "{\"success\":false,\"error\":\"File not found: $PATH_PARAM\",\"suggestion\":\"Use workspace.list and workspace.compile to build the binary first, then use the exact path from compile output.\"}"
        exit 1
    fi
else
    FULL_PATH_CMD="$FULL_PATH"
fi

cd "$WORKSPACE_ROOT"

# Parse args JSON to array
ARGS=()
if [[ -n "$ARGS_JSON" && "$ARGS_JSON" != "[]" ]]; then
    ARGS_STR=$(echo "$ARGS_JSON" | sed 's/[][]//g; s/"//g; s/,/ /g')
    read -ra ARGS <<< "$ARGS_STR"
fi

# Run with timeout
OUTPUT=$(timeout "$TIMEOUT" "$FULL_PATH_CMD" "${ARGS[@]}" 2>&1)
EXIT_CODE=$?

STDOUT=""
STDERR=""

# For simplicity, combine stdout/stderr
ESCAPED_OUTPUT=$(echo "$OUTPUT" | sed 's/\\/\\\\/g; s/\t/\\t/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n')

echo "{\"success\":true,\"stdout\":\"$ESCAPED_OUTPUT\",\"stderr\":\"\",\"exit_code\":$EXIT_CODE}"