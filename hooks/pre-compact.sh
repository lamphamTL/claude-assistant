#!/bin/bash
input=$(cat)
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

[ -z "$transcript" ] || [ ! -f "$transcript" ] && exit 0

total=0
while IFS= read -r line; do
  usage=$(echo "$line" | jq '.message.usage // empty' 2>/dev/null)
  [ -z "$usage" ] && continue
  in=$(echo "$usage" | jq '.input_tokens // 0')
  out=$(echo "$usage" | jq '.output_tokens // 0')
  cw=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
  cr=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
  total=$((total + in + out + cw + cr))
done < "$transcript"

mkdir -p ~/.claude/compaction
echo "{\"session_id\": \"$session_id\", \"tokens_before\": $total}" > ~/.claude/compaction/pre.json
