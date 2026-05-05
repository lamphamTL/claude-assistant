#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

last_stop=~/.claude/compaction/last-stop.json
[ ! -f "$last_stop" ] && exit 0

context_tokens=$(jq -r '.context_tokens // 0' "$last_stop")
mkdir -p ~/.claude/compaction
echo "{\"session_id\": \"$session_id\", \"tokens_before\": $context_tokens}" > ~/.claude/compaction/pre.json
