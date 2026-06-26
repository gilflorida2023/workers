#!/bin/bash
set -euo pipefail
echo "DEBUG: test_stdin3 started" >&2
echo "DEBUG: reading stdin..." >&2
while IFS= read -r line; do
    echo "DEBUG: got line: $line" >&2
done
echo "DEBUG: stdin read done" >&2
echo "SUCCESS"
