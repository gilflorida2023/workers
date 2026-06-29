#!/bin/bash
# workspace/search.sh - Search for patterns in workspace files

WORKSPACE_ROOT="/home/scout/projects/sandbox/workspace"
INPUT=$(cat)

PATTERN=$(echo "$INPUT" | grep -o '"pattern"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"pattern"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
SEARCH_PATH=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
FILE_PATTERN=$(echo "$INPUT" | grep -o '"file_pattern"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"file_pattern"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
CONTEXT_LINES=$(echo "$INPUT" | grep -o '"context_lines"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*"context_lines"[[:space:]]*:[[:space:]]*//')
CONTEXT_LINES=${CONTEXT_LINES:-2}

if [[ -z "$PATTERN" ]]; then
    echo '{"success":false,"error":"Missing pattern parameter"}'
    exit 1
fi

SEARCH_PATH=${SEARCH_PATH:-.}
FULL_SEARCH_PATH="${WORKSPACE_ROOT}/${SEARCH_PATH}"
FULL_SEARCH_PATH=$(realpath "$FULL_SEARCH_PATH" 2>/dev/null || echo "")

if [[ ! "$FULL_SEARCH_PATH" =~ ^"$WORKSPACE_ROOT" ]]; then
    echo '{"success":false,"error":"Path outside workspace"}'
    exit 1
fi

if [[ ! -d "$FULL_SEARCH_PATH" ]]; then
    echo '{"success":false,"error":"Search path not found"}'
    exit 1
fi

cd "$WORKSPACE_ROOT"

# Build grep command
GREP_CMD="grep -r -n -i"
if [[ -n "$FILE_PATTERN" ]]; then
    GREP_CMD="$GREP_CMD --include=\"$FILE_PATTERN\""
fi
GREP_CMD="$GREP_CMD -C $CONTEXT_LINES -- \"$PATTERN\" \"$SEARCH_PATH\" 2>/dev/null"

# Execute grep and capture output
RAW_OUTPUT=$(eval "$GREP_CMD" || true)

# Build JSON output
RESULTS="[]"
if [[ -n "$RAW_OUTPUT" ]]; then
    ROWS=""
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            FILE=$(echo "$line" | cut -d: -f1)
            LINE_NUM=$(echo "$line" | cut -d: -f2 | sed 's/[^0-9]//g')
            CONTENT=$(echo "$line" | cut -d: -f3-)
            ESCAPED_CONTENT=$(echo "$CONTENT" | sed 's/\\/\\\\/g; s/"/\\"/g')
            ESCAPED_FILE=$(echo "$FILE" | sed 's/\\/\\\\/g; s/"/\\"/g')
            ROW="{\"file\":\"$ESCAPED_FILE\",\"line\":${LINE_NUM:-0},\"content\":\"$ESCAPED_CONTENT\"}"
            if [[ -z "$ROWS" ]]; then
                ROWS="$ROW"
            else
                ROWS="$ROWS,$ROW"
            fi
        fi
    done <<< "$RAW_OUTPUT"
    RESULTS="[$ROWS]"
fi

echo "{\"success\":true,\"pattern\":\"$PATTERN\",\"matches\":$RESULTS}"