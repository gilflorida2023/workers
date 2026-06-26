#!/bin/bash
set -euo pipefail
echo "DEBUG: test_stdin started" >&2
read -r INPUT
echo "DEBUG: INPUT=$INPUT" >&2
echo "SUCCESS"
