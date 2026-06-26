#!/bin/bash
set -euo pipefail
echo "DEBUG: test_stdin2 started" >&2
echo "DEBUG: fd 0: $(ls -l /proc/self/fd/0 2>&1)" >&2
echo "DEBUG: fd 1: $(ls -l /proc/self/fd/1 2>&1)" >&2
echo "DEBUG: fd 2: $(ls -l /proc/self/fd/2 2>&1)" >&2
read -r INPUT
echo "DEBUG: INPUT=$INPUT" >&2
echo "SUCCESS"
