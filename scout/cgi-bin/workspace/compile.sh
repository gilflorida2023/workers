#!/bin/bash
# workspace/compile.sh - Compile source code in workspace

WORKSPACE_ROOT="/home/scout/projects/sandbox/workspace"
INPUT=$(cat)

PATH_PARAM=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
LANGUAGE=$(echo "$INPUT" | grep -o '"language"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"language"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
LANGUAGE=${LANGUAGE:-auto}

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

IS_DIR=false
if [[ -d "$FULL_PATH" ]]; then
    IS_DIR=true
elif [[ ! -f "$FULL_PATH" ]]; then
    echo "{\"success\":false,\"error\":\"Source file not found: $PATH_PARAM\",\"suggestion\":\"Use workspace.list to find actual filenames, then use EXACT name from list output. For Go projects with go.mod, try path='$(dirname $PATH_PARAM)' with language='auto'.\"}"
    exit 1
fi

cd "$WORKSPACE_ROOT"

# Auto-detect language from extension
if [[ "$LANGUAGE" == "auto" ]]; then
    if [[ "$IS_DIR" == true ]]; then
        # Directory: probe for project files
        if [[ -f "$FULL_PATH/go.mod" ]]; then
            LANGUAGE="go"
        elif [[ -f "$FULL_PATH/Cargo.toml" ]]; then
            LANGUAGE="rust"
        elif [[ -f "$FULL_PATH/Makefile" || -f "$FULL_PATH/CMakeLists.txt" ]]; then
            LANGUAGE="c"
        elif [[ -f "$FULL_PATH/pyproject.toml" || -f "$FULL_PATH/setup.py" || -f "$FULL_PATH/requirements.txt" ]]; then
            LANGUAGE="python"
        elif [[ -f "$FULL_PATH/package.json" ]]; then
            LANGUAGE="node"
        else
            LANGUAGE="unknown"
        fi
    else
        EXT="${PATH_PARAM##*.}"
        case "$EXT" in
            go) LANGUAGE="go" ;;
            py) LANGUAGE="python" ;;
            c) LANGUAGE="c" ;;
            cpp|cc|cxx) LANGUAGE="cpp" ;;
            rs) LANGUAGE="rust" ;;
            *) LANGUAGE="unknown" ;;
        esac
    fi
fi

BINARY=""
OUTPUT=""
SUCCESS=false

case "$LANGUAGE" in
    go)
        if [[ "$IS_DIR" == true ]]; then
            cd "$FULL_PATH"
            DIRNAME=$(basename "$FULL_PATH")
            OUTPUT=$(go build -o "$DIRNAME" . 2>&1)
            if [[ $? -eq 0 ]]; then
                SUCCESS=true
                BINARY="${PATH_PARAM}/${DIRNAME}"
            fi
        else
            BINARY="${PATH_PARAM%.*}"
            OUTPUT=$(go build -o "$BINARY" "$PATH_PARAM" 2>&1)
            if [[ $? -eq 0 ]]; then
                SUCCESS=true
            fi
        fi
        cd "$WORKSPACE_ROOT"
        ;;
    python)
        OUTPUT=$(python3 -m py_compile "$PATH_PARAM" 2>&1)
        if [[ $? -eq 0 ]]; then
            SUCCESS=true
            OUTPUT="Syntax OK"
        fi
        ;;
    c)
        BINARY="${PATH_PARAM%.*}"
        OUTPUT=$(gcc -o "$BINARY" "$PATH_PARAM" 2>&1)
        if [[ $? -eq 0 ]]; then
            SUCCESS=true
        fi
        ;;
    cpp)
        BINARY="${PATH_PARAM%.*}"
        OUTPUT=$(g++ -o "$BINARY" "$PATH_PARAM" 2>&1)
        if [[ $? -eq 0 ]]; then
            SUCCESS=true
        fi
        ;;
    rust)
        if [[ -f "Cargo.toml" ]]; then
            OUTPUT=$(cargo build 2>&1)
            if [[ $? -eq 0 ]]; then
                SUCCESS=true
                BINARY="target/debug/$(basename "$WORKSPACE_ROOT")"
            fi
        else
            OUTPUT="Cargo.toml not found"
        fi
        ;;
    *)
        OUTPUT="Unknown language: $LANGUAGE"
        SUGGESTION="Specify language explicitly (go, python, c, cpp, rust) or use a recognized file extension"
        ;;
esac

# Escape output for JSON
ESCAPED_OUTPUT=$(echo "$OUTPUT" | sed 's/\\/\\\\/g; s/\t/\\t/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n')

if [[ "$SUCCESS" == true ]]; then
    echo "{\"success\":true,\"language\":\"$LANGUAGE\",\"binary\":\"$BINARY\",\"output\":\"$ESCAPED_OUTPUT\"}"
else
    if [[ -n "$SUGGESTION" ]]; then
        ESCAPED_SUGGESTION=$(echo "$SUGGESTION" | sed 's/\\/\\\\/g; s/\t/\\t/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n')
        echo "{\"success\":false,\"language\":\"$LANGUAGE\",\"output\":\"$ESCAPED_OUTPUT\",\"suggestion\":\"$ESCAPED_SUGGESTION\"}"
    else
        echo "{\"success\":false,\"language\":\"$LANGUAGE\",\"output\":\"$ESCAPED_OUTPUT\"}"
    fi
fi