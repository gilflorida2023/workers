#!/bin/bash
set -euo pipefail

INPUT=$(cat)
WORKER1_HOST=$(echo "$INPUT" | jq -r '.worker1_host // "worker1:11434"')
WORKER2_HOST=$(echo "$INPUT" | jq -r '.worker2_host // "worker2:11434"')
MODEL=$(echo "$INPUT" | jq -r '.model // "qwen2.5:0.5b"')

ARENA_DIR="/home/scout/projects/workers/scout/contexts/arena"
BASELINE_DIR="$ARENA_DIR/baseline"
BASELINE_BIN="/home/scout/projects/workers/scout/bin/w1_baseline"
LEADERBOARD_FILE="/home/scout/projects/workers/scout/leaderboard.json"

exec 200>"$ARENA_DIR/match.lock"
flock -x 200

log() {
    local level=$1
    local msg=$2
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$level] $msg" >&2
}

die() {
    echo "{\"success\":false,\"error\":$(echo "$1" | jq -Rs .)}"
    exit 1
}

RANDOM_LIMIT=$(( (RANDOM % 1901) + 100 ))

EXPECTED_HASH=$( "$BASELINE_BIN" -limit "$RANDOM_LIMIT" -hash 2>/dev/null | tail -1 ) || die "baseline run failed"
log "INFO" "Proving ground: limit=$RANDOM_LIMIT expected_hash=$EXPECTED_HASH"

TOOLS_JSON=$(cat <<'TOOLS'
[
  {"type":"function","function":{"name":"read_file","description":"Read a file from your workspace.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"filename"}},"required":["path"]}}},
  {"type":"function","function":{"name":"write_file","description":"Write code to a file in your workspace.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"filename"}, "content":{"type":"string","description":"file content"}},"required":["path","content"]}}},
  {"type":"function","function":{"name":"compile","description":"Compile your Go code. Returns success or errors.","parameters":{"type":"object","properties":{}}}},
  {"type":"function","function":{"name":"run","description":"Run your compiled sieve program. Returns KAT hash, duration, memory.","parameters":{"type":"object","properties":{"limit":{"type":"integer","description":"sieve upper bound","default":100},"wheel":{"type":"integer","description":"wheel modulus: 30, 210, 2310, 30030","default":210}},"required":[]}}}
]
TOOLS
)

PROVE_PROMPT=$(cat <<PROMPT

You are a Go programmer in a tool-proficiency proving ground.
Your task: run the sieve program at limit=$RANDOM_LIMIT and report the KAT hash.

─── Tool Quick Reference ─────────────────────────────────────────
read_file(path)       "main.go", "internal/sieve/sieve.go", "go.mod"
write_file(path,content)  write code, then compile
compile()             go build; returns success or errors
run(limit, [wheel])   executes with -limit N [-wheel W]; returns:
                      → kat_hash (SHA-256 hex of prime list)
                      → result.duration_ms, result.primes, result.peak_mem_mb
────────────────────────────────────────────────────────────────

Steps:
1. Read the code to understand the structure
2. Compile the code
3. Run with limit=$RANDOM_LIMIT
4. Tell me the kat_hash from the run result

Your final response must contain ONLY the 64-character hex SHA-256 hash, nothing else.
PROMPT
)

seed_prove_sandbox() {
    local worker_id=$1
    local dir="$ARENA_DIR/prove_$worker_id"
    rm -rf "$dir"
    mkdir -p "$dir/internal/sieve"
    cp "$BASELINE_DIR/main.go" "$dir/main.go" 2>/dev/null || true
    cp "$BASELINE_DIR/go.mod" "$dir/go.mod" 2>/dev/null || true
    cp "$BASELINE_DIR/internal/sieve/sieve.go" "$dir/internal/sieve/sieve.go" 2>/dev/null || true
    log "INFO" "Seeded prove sandbox for $worker_id"
}

execute_tool() {
    local worker_id=$1
    local tool_name=$2
    local tool_args=$3
    local dir="$ARENA_DIR/prove_$worker_id"

    case "$tool_name" in
        read_file)
            local path
            path=$(echo "$tool_args" | jq -r '.path // ""')
            if [[ -z "$path" ]]; then
                echo '{"success":false,"error":"path required"}'
                return
            fi
            if [[ -f "$dir/$path" ]]; then
                echo "{\"success\":true,\"content\":$(cat "$dir/$path" | jq -Rs .)}"
            else
                echo "{\"success\":false,\"error\":\"file not found: $path\"}"
            fi
            ;;
        write_file)
            local path content
            path=$(echo "$tool_args" | jq -r '.path // ""')
            content=$(echo "$tool_args" | jq -r '.content // ""')
            if [[ -z "$path" ]]; then
                echo '{"success":false,"error":"path required"}'
                return
            fi
            mkdir -p "$(dirname "$dir/$path")"
            echo "$content" > "$dir/$path"
            chmod +x "$dir/$path" 2>/dev/null || true
            echo '{"success":true}'
            ;;
        compile)
            if [[ ! -f "$dir/go.mod" ]]; then
                echo '{"success":false,"error":"go.mod not found"}'
                return
            fi
            local output
            output=$(cd "$dir" && go build -o "$dir/worker" . 2>&1) || {
                echo "{\"success\":false,\"error\":$(echo "$output" | jq -Rs .)}"
                return
            }
            chmod +x "$dir/worker"
            echo '{"success":true}'
            ;;
        run)
            local run_limit run_wheel
            run_limit=$(echo "$tool_args" | jq -r '.limit // 100')
            run_wheel=$(echo "$tool_args" | jq -r '.wheel // 210')
            if [[ ! -x "$dir/worker" ]]; then
                echo '{"success":false,"error":"binary not found; compile first"}'
                return
            fi
            local stdout stderr exit_code
            stdout=$("$dir/worker" -limit "$run_limit" -wheel "$run_wheel" -hash 2>/dev/null) || exit_code=$?
            stderr=$("$dir/worker" -limit "$run_limit" -wheel "$run_wheel" 2>&1 >/dev/null) || true
            if [[ -n "$exit_code" && "$exit_code" -ne 0 ]]; then
                echo "{\"success\":false,\"error\":\"run failed with exit code $exit_code\",\"stderr\":$(echo "$stderr" | jq -Rs .)}"
                return
            fi
            local kat_hash result_json
            kat_hash=$(echo "$stdout" | tail -1)
            result_json=$(echo "$stderr" | head -1)
            if echo "$result_json" | jq empty 2>/dev/null; then
                echo "{\"success\":true,\"kat_hash\":$(echo "$kat_hash" | jq -Rs .),\"result\":$result_json}"
            else
                echo "{\"success\":true,\"kat_hash\":$(echo "$kat_hash" | jq -Rs .),\"raw\":$(echo "$result_json" | jq -Rs .)}"
            fi
            ;;
        *)
            echo "{\"success\":false,\"error\":\"unknown tool: $tool_name\"}"
            ;;
    esac
}

call_ollama() {
    local ollama_host=$1
    local messages_json=$2

    local payload
    payload=$(jq -n --arg model "$MODEL" --argjson tools "$TOOLS_JSON" --argjson messages "$messages_json" '{
        model: $model,
        messages: $messages,
        tools: $tools,
        stream: false
    }')

    local response
    response=$(curl -s --max-time 120 "http://$ollama_host/api/chat" -d "$payload" 2>/dev/null) || {
        echo "OLLAMA_ERROR:curl_failed"
        return
    }

    echo "$response"
}

run_prove_agent() {
    local worker_id=$1
    local ollama_host=$2

    log "INFO" "Running prove agent $worker_id on $ollama_host"

    local messages
    messages=$(jq -n \
        --arg system "$PROVE_PROMPT" \
        --arg worker_id "$worker_id" \
        --argjson limit "$RANDOM_LIMIT" \
        '[
            {"role":"system","content":$system},
            {"role":"user","content":("Run the sieve at limit=" + ($limit | tostring) + " and tell me the KAT hash.")}
        ]')

    local max_turns=10
    local turn=0
    local final_answer=""

    while [[ $turn -lt $max_turns ]]; do
        turn=$((turn + 1))
        log "INFO" "Prove $worker_id turn $turn/$max_turns"

        local response
        response=$(call_ollama "$ollama_host" "$messages")

        if [[ "$response" == "OLLAMA_ERROR:curl_failed" ]]; then
            log "ERROR" "Prove $worker_id: Ollama connection failed"
            echo "OLLAMA_FAIL"
            return
        fi

        local msg_role msg_content tool_calls_count
        msg_role=$(echo "$response" | jq -r '.message.role // "assistant"')
        msg_content=$(echo "$response" | jq -r '.message.content // ""')
        tool_calls_count=$(echo "$response" | jq '.message.tool_calls | length // 0')

        if [[ "$tool_calls_count" -gt 0 ]]; then
            local assistant_msg
            assistant_msg=$(echo "$response" | jq '{role: "assistant", content: .message.content, tool_calls: .message.tool_calls}')
            messages=$(echo "$messages" | jq --argjson msg "$assistant_msg" '. += [$msg]')

            for i in $(seq 0 $((tool_calls_count - 1))); do
                local tool_name tool_args
                tool_name=$(echo "$response" | jq -r ".message.tool_calls[$i].function.name")
                tool_args=$(echo "$response" | jq -c ".message.tool_calls[$i].function.arguments // {}")

                log "INFO" "Prove $worker_id: executing tool $tool_name"

                local tool_result
                tool_result=$(execute_tool "$worker_id" "$tool_name" "$tool_args" 2>/dev/null) || {
                    tool_result='{"success":false,"error":"tool execution failed"}'
                }

                messages=$(echo "$messages" | jq --arg name "$tool_name" --arg result "$tool_result" '. += [{"role": "tool", "content": $result}]')
            done
        elif [[ -n "$msg_content" && "$msg_content" != "null" ]]; then
            final_answer=$msg_content
            log "INFO" "Prove $worker_id: final answer: $final_answer"
            break
        else
            log "WARN" "Prove $worker_id: empty response, breaking"
            break
        fi
    done

    echo "$final_answer"
}

clean_hash() {
    echo "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | grep -oE '^[a-f0-9]{64}$' || echo ""
}

seed_prove_sandbox "worker1"
seed_prove_sandbox "worker2"

log "INFO" "Running worker1 prove agent"
W1_ANSWER=$(run_prove_agent "worker1" "$WORKER1_HOST")

log "INFO" "Running worker2 prove agent"
W2_ANSWER=$(run_prove_agent "worker2" "$WORKER2_HOST")

if [[ "$W1_ANSWER" == "OLLAMA_FAIL" && "$W2_ANSWER" == "OLLAMA_FAIL" ]]; then
    die "both workers failed to connect to Ollama"
fi

EXPECTED_CLEAN=$(clean_hash "$EXPECTED_HASH")
W1_CLEAN=$(clean_hash "$W1_ANSWER")
W2_CLEAN=$(clean_hash "$W2_ANSWER")

W1_CORRECT=false
W2_CORRECT=false
if [[ "$W1_CLEAN" == "$EXPECTED_CLEAN" ]]; then W1_CORRECT=true; fi
if [[ "$W2_CLEAN" == "$EXPECTED_CLEAN" ]]; then W2_CORRECT=true; fi

if [[ "$W1_CORRECT" == "true" && "$W2_CORRECT" == "true" ]]; then
    WINNER="tie"
elif [[ "$W1_CORRECT" == "true" ]]; then
    WINNER="worker1"
elif [[ "$W2_CORRECT" == "true" ]]; then
    WINNER="worker2"
else
    WINNER="none"
fi

log "INFO" "Prove results: w1_correct=$W1_CORRECT w2_correct=$W2_CORRECT winner=$WINNER"

jq -n \
    --argjson limit "$RANDOM_LIMIT" \
    --arg expected "$EXPECTED_CLEAN" \
    --arg w1_answer "$W1_ANSWER" \
    --arg w2_answer "$W2_ANSWER" \
    --argjson w1_correct "$W1_CORRECT" \
    --argjson w2_correct "$W2_CORRECT" \
    --arg winner "$WINNER" \
    '{
        success: true,
        challenge: {limit: $limit, expected_hash: $expected},
        worker1: {answer: $w1_answer, correct: $w1_correct},
        worker2: {answer: $w2_answer, correct: $w2_correct},
        winner: $winner
    }'

flock -u 200
