#!/bin/bash
# wiki_lookup.sh - Look up tool/guide documentation

WIKI_ROOT="/home/scout/projects/sandbox/workspace/.wiki"
INPUT=$(cat)

TOPIC=$(echo "$INPUT" | grep -o '"topic"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"topic"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [[ -z "$TOPIC" ]]; then
    echo '{"success":false,"error":"Missing topic parameter"}'
    exit 1
fi

# Search for topic in tools and guides
FOUND=""
CONTENT=""

if [[ -f "$WIKI_ROOT/tools/$TOPIC.md" ]]; then
    CONTENT=$(cat "$WIKI_ROOT/tools/$TOPIC.md")
    FOUND="tools/$TOPIC.md"
elif [[ -f "$WIKI_ROOT/guides/$TOPIC.md" ]]; then
    CONTENT=$(cat "$WIKI_ROOT/guides/$TOPIC.md")
    FOUND="guides/$TOPIC.md"
elif [[ -f "$WIKI_ROOT/tools/${TOPIC}.md" ]]; then
    CONTENT=$(cat "$WIKI_ROOT/tools/${TOPIC}.md")
    FOUND="tools/${TOPIC}.md"
elif [[ -f "$WIKI_ROOT/guides/${TOPIC}.md" ]]; then
    CONTENT=$(cat "$WIKI_ROOT/guides/${TOPIC}.md")
    FOUND="guides/${TOPIC}.md"
fi

if [[ -z "$CONTENT" ]]; then
    echo '{"success":false,"error":"Topic not found"}'
    exit 1
fi

# Escape for JSON
ESCAPED_CONTENT=$(echo "$CONTENT" | sed 's/\\/\\\\/g; s/\t/\\t/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n')

echo "{\"success\":true,\"topic\":\"$TOPIC\",\"file\":\"$FOUND\",\"content\":\"$ESCAPED_CONTENT\"}"