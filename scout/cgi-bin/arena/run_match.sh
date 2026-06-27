#!/bin/bash
set -euo pipefail

INPUT=$(cat)
WORKER1_HOST=$(echo "$INPUT" | jq -r '.worker1_host // "worker1:11434"')
WORKER2_HOST=$(echo "$INPUT" | jq -r '.worker2_host // "worker2:11434"')
MODEL=$(echo "$INPUT" | jq -r '.model // "qwen2.5:0.5b"')
FORCE=$(echo "$INPUT" | jq -r '.force // false')

ARENA_DIR="/home/scout/projects/workers/scout/contexts/arena"
BASELINE_DIR="$ARENA_DIR/baseline"
TIER_FILE="$ARENA_DIR/tier.json"
MATCHES_FILE="$ARENA_DIR/matches.jsonl"
LOCK_FILE="$ARENA_DIR/match.lock"
LEADERBOARD_FILE="/home/scout/projects/workers/scout/leaderboard.json"
SCOUT_BIN_DIR="/home/scout/projects/workers/scout/bin"
SCOUT_CGI_DIR="/home/scout/projects/workers/scout/cgi-bin"

exec 200>"$LOCK_FILE"
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

# ─── Read tier ───────────────────────────────────────────────
if [[ ! -f "$TIER_FILE" ]]; then
    die "tier.json not found; arena not initialized"
fi

TIER=$(cat "$TIER_FILE" | tr -d '\n')
LIMIT=$(echo "$TIER" | jq -r '.limit // 541')
TIER_NAME=$(echo "$TIER" | jq -r '.tier // "min"')
log "INFO" "Starting match at tier=$TIER_NAME limit=$LIMIT"

# ─── Ensure baseline exists ──────────────────────────────────
if [[ ! -f "$BASELINE_DIR/internal/sieve/sieve.go" || ! -f "$BASELINE_DIR/main.go" ]]; then
    die "baseline code missing in $BASELINE_DIR"
fi

# ─── Worker agent functions ──────────────────────────────────

TOOLS_JSON=$(cat <<'TOOLS'
[
  {"type":"function","function":{"name":"read_file","description":"Read a file from your workspace. Files: sieve.go (sieve implementation), main.go (entry point), go.mod.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"filename"}},"required":["path"]}}},
  {"type":"function","function":{"name":"write_file","description":"Write code to a file in your workspace. Use this to modify the sieve algorithm.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"filename"}, "content":{"type":"string","description":"file content"}},"required":["path","content"]}}},
  {"type":"function","function":{"name":"compile","description":"Compile your Go code in the workspace. Returns success or compilation errors.","parameters":{"type":"object","properties":{}}}},
  {"type":"function","function":{"name":"run","description":"Run your compiled sieve program. Returns KAT hash, prime count, duration, memory.","parameters":{"type":"object","properties":{"limit":{"type":"integer","description":"sieve upper bound","default":100},"wheel":{"type":"integer","description":"wheel modulus: 30, 210 (default), 2310, or 30030","default":210}},"required":[]}}},
  {"type":"function","function":{"name":"submit_for_match","description":"Submit your current code as your entry for the match. Call this when you are satisfied with your improvement.","parameters":{"type":"object","properties":{}}}},
  {"type":"function","function":{"name":"get_leaderboard","description":"View the current leaderboard.","parameters":{"type":"object","properties":{}}}}
]
TOOLS
)

SYSTEM_PROMPT=$(cat <<PROMPT

You are an expert Go programmer and algorithm optimizer in a competitive coevolutionary arena.
Your goal: improve a prime sieve algorithm for speed and memory efficiency.

The current problem: Sieve of Eratosthenes up to limit=$LIMIT
The project has two files: main.go (CLI entry point) and internal/sieve/sieve.go (sieve algorithm).
The baseline uses bit-packed segmented sieve with wheel-210 factorization in internal/sieve/sieve.go.

─── Tool Quick Reference ─────────────────────────────────────────
read_file(path)       "internal/sieve/sieve.go", "main.go", "go.mod"
write_file(path,content)  write code, then compile to test it
compile()             go build in sandbox; returns success or errors
run(limit, [wheel])   executes with -limit N [-wheel W]; returns:
                      → kat_hash (SHA-256 hex of prime list)
                      → result.duration_ms, result.primes, result.peak_mem_mb
                      Use limit=100 for quick test, wheel=30/210/2310/30030
submit_for_match()    git-commit your entry (call when ready)
get_leaderboard()     see standings
────────────────────────────────────────────────────────────────
Workflow: read → edit → compile → run → repeat

Strategy tips:
- Start by reading internal/sieve/sieve.go to understand the algorithm
- Edit internal/sieve/sieve.go to improve the sieve; edit main.go only if needed
- Try optimizations: larger wheels (2310, 30030), concurrent goroutines, better memory layout
- Compile and test after each change
- Always compile before run
- Submit when you have a genuine improvement
- Higher sieve limits reward better algorithms
PROMPT
)

seed_sandbox() {
    local worker_id=$1
    local dir="$ARENA_DIR/$worker_id"
    if [[ -f "$dir/internal/sieve/sieve.go" ]]; then
        log "INFO" "Sandbox already seeded for $worker_id, skipping"
        return
    fi
    mkdir -p "$dir/internal/sieve"
    echo "worker" > "$dir/.gitignore"
    echo "simplesieve" >> "$dir/.gitignore"
    cp "$BASELINE_DIR/main.go" "$dir/main.go" 2>/dev/null || true
    cp "$BASELINE_DIR/go.mod" "$dir/go.mod" 2>/dev/null || true
    cp "$BASELINE_DIR/internal/sieve/sieve.go" "$dir/internal/sieve/sieve.go" 2>/dev/null || true
    rm -f "$dir/.submit_score"
    log "INFO" "Seeded sandbox for $worker_id"
}
execute_tool() {
    local worker_id=$1
    local tool_name=$2
    local tool_args=$3

    case "$tool_name" in
        read_file)
            local path
            path=$(echo "$tool_args" | jq -r '.path // ""')
            if [[ -z "$path" ]]; then
                echo '{"success":false,"error":"path required"}'
                return
            fi
            SCOUT_WORKER_ID="$worker_id" /home/scout/projects/workers/scout/cgi-bin/arena/read_file.sh <<< "{\"worker_id\":$(echo "$worker_id" | jq -Rs .),\"path\":$(echo "$path" | jq -Rs .)}"
            ;;
        write_file)
            local path content
            path=$(echo "$tool_args" | jq -r '.path // ""')
            content=$(echo "$tool_args" | jq -r '.content // ""')
            if [[ -z "$path" ]]; then
                echo '{"success":false,"error":"path required"}'
                return
            fi
            /home/scout/projects/workers/scout/cgi-bin/arena/write_file.sh <<< "{\"worker_id\":$(echo "$worker_id" | jq -Rs .),\"path\":$(echo "$path" | jq -Rs .),\"content\":$(echo "$content" | jq -Rs .)}"
            ;;
        compile)
            local dir="$ARENA_DIR/$worker_id"
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
            local dir="$ARENA_DIR/$worker_id"
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
        submit_for_match)
            local dir="$ARENA_DIR/$worker_id"
            if [[ ! -f "$dir/internal/sieve/sieve.go" ]]; then
                echo '{"success":false,"error":"no code to submit"}'
                return
            fi
            /home/scout/projects/workers/scout/cgi-bin/arena/submit.sh <<< "{\"worker_id\":$(echo "$worker_id" | jq -Rs .)}"
            ;;
        get_leaderboard)
            /home/scout/projects/workers/scout/cgi-bin/arena/leaderboard.sh <<< '{}'
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
    response=$(curl -s --max-time 300 "http://$ollama_host/api/chat" -d "$payload" 2>/dev/null) || {
        echo "OLLAMA_ERROR:curl_failed"
        return
    }

    echo "$response"
}

run_worker_agent() {
    local worker_id=$1
    local ollama_host=$2
    local dir="$ARENA_DIR/$worker_id"

    log "INFO" "Running worker agent $worker_id on $ollama_host"

    # Ensure sandbox is seeded
    if [[ ! -f "$dir/internal/sieve/sieve.go" ]]; then
        seed_sandbox "$worker_id"
    fi

    # Build messages
    local messages
    messages=$(jq -n \
        --arg system "$SYSTEM_PROMPT" \
        --arg worker_id "$worker_id" \
        --argjson limit "$LIMIT" \
        '[
            {"role":"system","content":$system},
            {"role":"user","content":"You are Worker '"$worker_id"'. Improve the prime sieve algorithm up to limit='"$LIMIT"'. Read the baseline code first, then iteratively improve it. Compile and test each change. Submit when you have a genuine improvement."}
        ]')

    local max_turns=30
    local turn=0
    local final_content=""

    while [[ $turn -lt $max_turns ]]; do
        turn=$((turn + 1))
        log "INFO" "Worker $worker_id turn $turn/$max_turns"

        local response
        response=$(call_ollama "$ollama_host" "$messages")

        if [[ "$response" == "OLLAMA_ERROR:curl_failed" ]]; then
            log "ERROR" "Worker $worker_id: Ollama connection failed to $ollama_host"
            echo '{"success":false,"error":"Ollama connection failed"}'
            return
        fi

        local msg_role msg_content tool_calls_count
        msg_role=$(echo "$response" | jq -r '.message.role // "assistant"')
        msg_content=$(echo "$response" | jq -r '.message.content // ""')
        tool_calls_count=$(echo "$response" | jq '.message.tool_calls | length // 0')

        log "INFO" "Worker $worker_id: role=$msg_role tools=$tool_calls_count content_len=${#msg_content}"

        if [[ "$tool_calls_count" -gt 0 ]]; then
            # Add assistant message with tool_calls to conversation
            local assistant_msg
            assistant_msg=$(echo "$response" | jq '{role: "assistant", content: .message.content, tool_calls: .message.tool_calls}')
            messages=$(echo "$messages" | jq --argjson msg "$assistant_msg" '. += [$msg]')

            # Execute each tool call
            for i in $(seq 0 $((tool_calls_count - 1))); do
                local tool_name tool_args
                tool_name=$(echo "$response" | jq -r ".message.tool_calls[$i].function.name")
                tool_args=$(echo "$response" | jq -c ".message.tool_calls[$i].function.arguments // {}")

                log "INFO" "Worker $worker_id: executing tool $tool_name"

                local tool_result
                tool_result=$(execute_tool "$worker_id" "$tool_name" "$tool_args" 2>/dev/null) || {
                    tool_result='{"success":false,"error":"tool execution failed"}'
                }

                messages=$(echo "$messages" | jq --arg name "$tool_name" --arg result "$tool_result" '. += [{"role": "tool", "content": $result}]')
            done
        elif [[ -n "$msg_content" && "$msg_content" != "null" ]]; then
            final_content=$msg_content
            messages=$(echo "$messages" | jq --arg content "$msg_content" '. += [{"role": "assistant", "content": $content}]')
            log "INFO" "Worker $worker_id: final response received"
            break
        else
            log "WARN" "Worker $worker_id: empty response, breaking"
            break
        fi
    done

    if [[ $turn -ge $max_turns ]]; then
        log "WARN" "Worker $worker_id: max turns reached"
    fi

    # Ensure code is submitted
    local dir="$ARENA_DIR/$worker_id"
    if [[ -d "$dir/.git" ]]; then
        git -C "$dir" add -A
        if ! git -C "$dir" diff --cached --quiet; then
            git -C "$dir" commit -q -m "auto-submit at end of turn" 2>/dev/null || true
            log "INFO" "Worker $worker_id: auto-submitted code"
        fi
    fi

    echo "{\"success\":true,\"worker_id\":$(echo "$worker_id" | jq -Rs .),\"turns\":$turn,\"final\":$(echo "$final_content" | jq -Rs .)}"
}

# ─── Run both workers ────────────────────────────────────────

log "INFO" "Seeding sandboxes"
seed_sandbox "worker1"
seed_sandbox "worker2"

log "INFO" "Running worker 1 agent"
W1_RESULT=$(run_worker_agent "worker1" "$WORKER1_HOST")
W1_SUCCESS=$(echo "$W1_RESULT" | jq -r '.success // false')

log "INFO" "Running worker 2 agent"
W2_RESULT=$(run_worker_agent "worker2" "$WORKER2_HOST")
W2_SUCCESS=$(echo "$W2_RESULT" | jq -r '.success // false')

if [[ "$W1_SUCCESS" != "true" || "$W2_SUCCESS" != "true" ]]; then
    die "worker agent failed: w1=$W1_SUCCESS w2=$W2_SUCCESS"
fi

# ─── Compile both final submissions ──────────────────────────

log "INFO" "Compiling final submissions"

W1_DIR="$ARENA_DIR/worker1"
W2_DIR="$ARENA_DIR/worker2"

W1_COMPILE=$(cd "$W1_DIR" && go build -o "$W1_DIR/worker" . 2>&1) || die "worker1 compile failed: $W1_COMPILE"
W2_COMPILE=$(cd "$W2_DIR" && go build -o "$W2_DIR/worker" . 2>&1) || die "worker2 compile failed: $W2_COMPILE"

chmod +x "$W1_DIR/worker" "$W2_DIR/worker"

# ─── Run both at the match limit ─────────────────────────────

log "INFO" "Running both workers at limit=$LIMIT"

W1_STDOUT=$("$W1_DIR/worker" -limit "$LIMIT" -hash 2>/dev/null) || true
W1_STDERR=$("$W1_DIR/worker" -limit "$LIMIT" 2>&1 >/dev/null) || true
W1_KAT=$(echo "$W1_STDOUT" | tail -1)
W1_METRICS=$(echo "$W1_STDERR" | head -1)

W2_STDOUT=$("$W2_DIR/worker" -limit "$LIMIT" -hash 2>/dev/null) || true
W2_STDERR=$("$W2_DIR/worker" -limit "$LIMIT" 2>&1 >/dev/null) || true
W2_KAT=$(echo "$W2_STDOUT" | tail -1)
W2_METRICS=$(echo "$W2_STDERR" | head -1)

# ─── Also run baseline for comparison ────────────────────────

BASELINE_BIN="$SCOUT_BIN_DIR/w1_baseline"
B_STDOUT=$("$BASELINE_BIN" -limit "$LIMIT" -hash 2>/dev/null) || true
B_STDERR=$("$BASELINE_BIN" -limit "$LIMIT" 2>&1 >/dev/null) || true
B_KAT=$(echo "$B_STDOUT" | tail -1)
B_METRICS=$(echo "$B_STDERR" | head -1)

log "INFO" "Worker1 KAT=$W1_KAT Worker2 KAT=$W2_KAT Baseline KAT=$B_KAT"
log "INFO" "Worker1 metrics=$W1_METRICS"
log "INFO" "Worker2 metrics=$W2_METRICS"
log "INFO" "Baseline metrics=$B_METRICS"

# ─── Git diff analysis ──────────────────────────────────────

log "INFO" "Computing git diffs"

W1_DIFF_STAT=""
W1_DIFF_LINES=0
if git -C "$W1_DIR" log --oneline 2>/dev/null | head -3 | grep -q "."; then
W1_DIFF_STAT=$(git -C "$W1_DIR" diff HEAD~1 --stat 2>/dev/null || echo "")
W1_DIFF_LINES=$(( $(git -C "$W1_DIR" diff HEAD~1 2>/dev/null | wc -l) || echo 0))
fi

W2_DIFF_STAT=""
W2_DIFF_LINES=0
if git -C "$W2_DIR" log --oneline 2>/dev/null | head -3 | grep -q "."; then
W2_DIFF_STAT=$(git -C "$W2_DIR" diff HEAD~1 --stat 2>/dev/null || echo "")
W2_DIFF_LINES=$(( $(git -C "$W2_DIR" diff HEAD~1 2>/dev/null | wc -l) || echo 0))
fi

# ─── Score calculation ───────────────────────────────────────

# Parse metrics
w1_dur=$(echo "$W1_METRICS" | jq -r '.duration_ms // 999999' 2>/dev/null || echo 999999)
w1_prime=$(echo "$W1_METRICS" | jq -r '.primes // 0' 2>/dev/null || echo 0)
w1_mem=$(echo "$W1_METRICS" | jq -r '.peak_mem_mb // 999' 2>/dev/null || echo 999)

w2_dur=$(echo "$W2_METRICS" | jq -r '.duration_ms // 999999' 2>/dev/null || echo 999999)
w2_prime=$(echo "$W2_METRICS" | jq -r '.primes // 0' 2>/dev/null || echo 0)
w2_mem=$(echo "$W2_METRICS" | jq -r '.peak_mem_mb // 999' 2>/dev/null || echo 999)

b_dur=$(echo "$B_METRICS" | jq -r '.duration_ms // 1' 2>/dev/null || echo 1)
b_prime=$(echo "$B_METRICS" | jq -r '.primes // 0' 2>/dev/null || echo 0)
b_mem=$(echo "$B_METRICS" | jq -r '.peak_mem_mb // 1' 2>/dev/null || echo 1)

# Expected prime count for this limit
EXPECTED_PRIMES=$b_prime
if [[ "$EXPECTED_PRIMES" -eq 0 ]]; then
    EXPECTED_PRIMES=$(echo "scale=0; $LIMIT / l($LIMIT)" | bc -l 2>/dev/null | cut -d. -f1 || echo 100)
fi

# Originality score: 0-20 based on diff lines
calc_originality() {
    local lines=$1
    if [[ $lines -ge 50 ]]; then echo 20
    elif [[ $lines -ge 20 ]]; then echo 15
    elif [[ $lines -ge 10 ]]; then echo 10
    elif [[ $lines -ge 5 ]]; then echo 5
    else echo 0
    fi
}

# Correctness: 20 if KAT matches expected
calc_correctness() {
    local kat=$1
    if [[ "$kat" == "$B_KAT" ]]; then echo 20; else echo 0; fi
}

# Speed score: 0-40
calc_speed() {
    local my_dur=$1
    local base_dur=$2
    if [[ "$base_dur" -le 0 ]]; then base_dur=1; fi
    if [[ "$my_dur" -le 0 ]]; then my_dur=999999; fi
    local ratio
    ratio=$(echo "scale=4; $base_dur / $my_dur" | bc 2>/dev/null || echo 0.5)
    local score
    score=$(echo "scale=0; ($ratio * 40) / 1" | bc 2>/dev/null || echo 0)
    if [[ "$score" -gt 40 ]]; then score=40; fi
    echo "$score"
}

# Memory score: 0-20
calc_memory() {
    local my_mem=$1
    local base_mem=$2
    if [[ "$base_mem" -le 0 ]]; then base_mem=1; fi
    if [[ "$my_mem" -le 0 ]]; then my_mem=999; fi
    local ratio
    ratio=$(echo "scale=4; $base_mem / $my_mem" | bc 2>/dev/null || echo 0.5)
    local score
    score=$(echo "scale=0; ($ratio * 20) / 1" | bc 2>/dev/null || echo 0)
    if [[ "$score" -gt 20 ]]; then score=20; fi
    echo "$score"
}

W1_ORIG=$(calc_originality "$W1_DIFF_LINES")
W2_ORIG=$(calc_originality "$W2_DIFF_LINES")
W1_CORR=$(calc_correctness "$W1_KAT")
W2_CORR=$(calc_correctness "$W2_KAT")
W1_SPD=$(calc_speed "$w1_dur" "$b_dur")
W2_SPD=$(calc_speed "$w2_dur" "$b_dur")
W1_MEM=$(calc_memory "$w1_mem" "$b_mem")
W2_MEM=$(calc_memory "$w2_mem" "$b_mem")

W1_SCORE=$((W1_ORIG + W1_CORR + W1_SPD + W1_MEM))
W2_SCORE=$((W2_ORIG + W2_CORR + W2_SPD + W2_MEM))

if [[ "$W1_SCORE" -gt "$W2_SCORE" ]]; then
    WINNER="worker1"
elif [[ "$W2_SCORE" -gt "$W1_SCORE" ]]; then
    WINNER="worker2"
else
    WINNER="tie"
fi

log "INFO" "Scores: worker1=$W1_SCORE (orig=$W1_ORIG corr=$W1_CORR spd=$W1_SPD mem=$W1_MEM) worker2=$W2_SCORE (orig=$W2_ORIG corr=$W2_CORR spd=$W2_SPD mem=$W2_MEM)"
log "INFO" "Winner: $WINNER"

# Save scores to worker dirs
echo "$W1_SCORE" > "$W1_DIR/.submit_score"
echo "$W2_SCORE" > "$W2_DIR/.submit_score"

# ─── Record match ────────────────────────────────────────────

MATCH_ID="match_$(date +%s)"

# Build match record as proper JSON using jq
jq -n \
    --arg id "$MATCH_ID" \
    --arg tier "$TIER_NAME" \
    --argjson limit "$LIMIT" \
    --argjson w1s "$W1_SCORE" \
    --argjson w2s "$W2_SCORE" \
    --argjson w1o "$W1_ORIG" \
    --argjson w1c "$W1_CORR" \
    --argjson w1sp "$W1_SPD" \
    --argjson w1m "$W1_MEM" \
    --argjson w1d "$w1_dur" \
    --argjson w1mb "$w1_mem" \
    --argjson w1dl "$W1_DIFF_LINES" \
    --argjson w1p "$w1_prime" \
    --arg w1k "$W1_KAT" \
    --argjson w2o "$W2_ORIG" \
    --argjson w2c "$W2_CORR" \
    --argjson w2sp "$W2_SPD" \
    --argjson w2m "$W2_MEM" \
    --argjson w2d "$w2_dur" \
    --argjson w2mb "$w2_mem" \
    --argjson w2dl "$W2_DIFF_LINES" \
    --argjson w2p "$w2_prime" \
    --arg w2k "$W2_KAT" \
    --argjson bd "$b_dur" \
    --argjson bp "$b_prime" \
    --arg bk "$B_KAT" \
    --arg winner "$WINNER" \
    '{
        match_id: $id,
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        tier: $tier,
        limit: $limit,
        worker_a: "worker1",
        worker_b: "worker2",
        winner: $winner,
        scores: {worker1: $w1s, worker2: $w2s},
        breakdown: {
            worker1: {originality: $w1o, correctness: $w1c, speed: $w1sp, memory: $w1m, duration_ms: $w1d, memory_mb: $w1mb, diff_lines: $w1dl, primes: $w1p, kat: $w1k},
            worker2: {originality: $w2o, correctness: $w2c, speed: $w2sp, memory: $w2m, duration_ms: $w2d, memory_mb: $w2mb, diff_lines: $w2dl, primes: $w2p, kat: $w2k}
        },
        baseline: {duration_ms: $bd, primes: $bp, kat: $bk}
    }' > /tmp/arena_this_match.json

MATCH_RECORD=$(cat /tmp/arena_this_match.json)
echo "$MATCH_RECORD" >> "$MATCHES_FILE"
log "INFO" "Match recorded: $MATCH_ID"

# ─── Update leaderboard ─────────────────────────────────────

update_leaderboard() {
    local worker_id=$1
    local score=$2
    local winner=$3

    local tmp
    tmp=$(mktemp) || die "failed to create temp file"

    if [[ ! -f "$LEADERBOARD_FILE" ]]; then
        echo '{"workers":[],"matches":[]}' > "$LEADERBOARD_FILE"
    fi

    python3 <<PYEOF 2>/dev/null || log "WARN" "leaderboard update failed for $worker_id"
import json, sys

with open("$LEADERBOARD_FILE") as f:
    data = json.load(f)

worker_id = "$worker_id"
score = $score
winner = "$winner"

worker = None
for w in data["workers"]:
    if w["id"] == worker_id:
        worker = w
        break

if worker is None:
    wins = 1 if winner == worker_id else 0
    losses = 0
    if winner != "tie" and winner != worker_id:
        losses = 1
    data["workers"].append({
        "id": worker_id,
        "score": score,
        "wins": wins,
        "losses": losses,
        "matches": 1,
        "best_score": score
    })
else:
    if winner == worker_id:
        worker["wins"] += 1
    elif winner != "tie":
        worker["losses"] += 1
    worker["score"] += score
    worker["matches"] += 1
    if score > worker["best_score"]:
        worker["best_score"] = score

data["workers"].sort(key=lambda w: -w["score"])

with open("$LEADERBOARD_FILE", "w") as f:
    json.dump(data, f, indent=2)
PYEOF

    log "INFO" "Leaderboard updated for $worker_id"
}

update_leaderboard "worker1" "$W1_SCORE" "$WINNER"
update_leaderboard "worker2" "$W2_SCORE" "$WINNER"

# Add match record to leaderboard
python3 <<PYEOF 2>/dev/null || log "WARN" "failed to add match to leaderboard"
import json
with open("$LEADERBOARD_FILE") as f:
    data = json.load(f)
with open("/tmp/arena_this_match.json") as f:
    match = json.load(f)
data["matches"].append(match)
with open("$LEADERBOARD_FILE", "w") as f:
    json.dump(data, f, indent=2)
PYEOF

log "INFO" "Match added to leaderboard"

# ─── Record match in baseline git too (for audit trail) ──────
if [[ -d "$BASELINE_DIR/.git" ]]; then
    echo "$MATCH_RECORD" >> "$ARENA_DIR/mutations.jsonl" 2>/dev/null || true
    cp "$MATCHES_FILE" "$BASELINE_DIR/matches.jsonl" 2>/dev/null || true
    git -C "$BASELINE_DIR" add -A 2>/dev/null || true
    git -C "$BASELINE_DIR" commit -q -m "match: $WINNER wins at tier $TIER_NAME" 2>/dev/null || true
fi

# ─── Output result ──────────────────────────────────────────

flock -u 200

echo "$MATCH_RECORD"
