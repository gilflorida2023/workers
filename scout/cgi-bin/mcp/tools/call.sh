#!/bin/bash
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.name // ""')
ARGS=$(echo "$INPUT" | jq -c '.arguments // {}')

case "$TOOL_NAME" in
    worker1.compile)
        /home/scout/projects/workers/scout/cgi-bin/worker1/compile.sh <<< "$ARGS"
        ;;
    worker1.run)
        /home/scout/projects/workers/scout/cgi-bin/worker1/run.sh <<< "$ARGS"
        ;;
    worker1.verify)
        /home/scout/projects/workers/scout/cgi-bin/worker1/verify.sh <<< "$ARGS"
        ;;
    worker1.config)
        /home/scout/projects/workers/scout/cgi-bin/worker1/config.sh <<< "$ARGS"
        ;;
    worker2.compile)
        /home/scout/projects/workers/scout/cgi-bin/worker2/compile.sh <<< "$ARGS"
        ;;
    worker2.run)
        /home/scout/projects/workers/scout/cgi-bin/worker2/run.sh <<< "$ARGS"
        ;;
    worker2.verify)
        /home/scout/projects/workers/scout/cgi-bin/worker2/verify.sh <<< "$ARGS"
        ;;
    worker2.config)
        /home/scout/projects/workers/scout/cgi-bin/worker2/config.sh <<< "$ARGS"
        ;;
    baseline.compile)
        /home/scout/projects/workers/scout/cgi-bin/baseline/compile.sh <<< "$ARGS"
        ;;
    baseline.run)
        /home/scout/projects/workers/scout/cgi-bin/baseline/run.sh <<< "$ARGS"
        ;;
    baseline.verify)
        /home/scout/projects/workers/scout/cgi-bin/baseline/verify.sh <<< "$ARGS"
        ;;
    baseline.config)
        /home/scout/projects/workers/scout/cgi-bin/baseline/config.sh <<< "$ARGS"
        ;;
    kat_verify.verify)
        /home/scout/projects/workers/scout/cgi-bin/kat_verify/verify.sh <<< "$ARGS"
        ;;
    manifest.get)
        /home/scout/projects/workers/scout/cgi-bin/manifest/get.sh <<< "$ARGS"
        ;;
    judge.heuristic)
        /home/scout/projects/workers/scout/cgi-bin/judge/heuristic.sh <<< "$ARGS"
        ;;
    arena.get_context)
        /home/scout/projects/workers/scout/cgi-bin/arena/get_context.sh <<< "$ARGS"
        ;;
    arena.read_file)
        /home/scout/projects/workers/scout/cgi-bin/arena/read_file.sh <<< "$ARGS"
        ;;
    arena.write_file)
        /home/scout/projects/workers/scout/cgi-bin/arena/write_file.sh <<< "$ARGS"
        ;;
    arena.submit)
        /home/scout/projects/workers/scout/cgi-bin/arena/submit.sh <<< "$ARGS"
        ;;
    arena.leaderboard)
        /home/scout/projects/workers/scout/cgi-bin/arena/leaderboard.sh <<< "$ARGS"
        ;;
    arena.status)
        /home/scout/projects/workers/scout/cgi-bin/arena/status.sh <<< "$ARGS"
        ;;
    arena.match_result)
        /home/scout/projects/workers/scout/cgi-bin/arena/match_result.sh <<< "$ARGS"
        ;;
    arena.run_match)
        /home/scout/projects/workers/scout/cgi-bin/arena/run_match.sh <<< "$ARGS"
        ;;
    *)
        echo '{"success":false,"error":"Unknown tool: '"$TOOL_NAME"'","retryable":false}'
        exit 1
        ;;
esac
