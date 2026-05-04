#!/bin/bash
input=$(cat)
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

[ -z "$transcript" ] || [ ! -f "$transcript" ] && exit 0

pre_file=~/.claude/compaction/pre.json
[ ! -f "$pre_file" ] && exit 0

pre_session=$(jq -r '.session_id // empty' "$pre_file")
tokens_before=$(jq -r '.tokens_before // 0' "$pre_file")

[ "$pre_session" != "$session_id" ] && exit 0

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

reduced=$((tokens_before - total))

echo "{\"session_id\": \"$session_id\", \"tokens_before\": $tokens_before, \"tokens_after\": $total, \"reduced\": $reduced}" \
  > ~/.claude/compaction/result.json

rm -f ~/.claude/compaction/pre.json
