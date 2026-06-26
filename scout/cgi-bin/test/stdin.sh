#!/bin/bash
echo "DEBUG: stdin test started" >&2
read -r INPUT
echo "DEBUG: INPUT=$INPUT" >&2
echo '{"success":true,"input":"'"$INPUT"'"}'
