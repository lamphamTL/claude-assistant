#!/bin/bash
input=$(cat)
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  exit 0
fi

total_input=0
total_output=0
total_cache_write=0
total_cache_read=0

while IFS= read -r line; do
  usage=$(echo "$line" | jq '.message.usage // empty' 2>/dev/null)
  [ -z "$usage" ] && continue
  total_input=$((total_input + $(echo "$usage" | jq '.input_tokens // 0')))
  total_output=$((total_output + $(echo "$usage" | jq '.output_tokens // 0')))
  total_cache_write=$((total_cache_write + $(echo "$usage" | jq '.cache_creation_input_tokens // 0')))
  total_cache_read=$((total_cache_read + $(echo "$usage" | jq '.cache_read_input_tokens // 0')))
done < "$transcript"

# Approximate cost for claude-sonnet-4-6 (USD per million tokens):
#   input $3, output $15, cache write $3.75, cache read $0.30
cost=$(echo "scale=4; ($total_input * 3 + $total_output * 15 + $total_cache_write * 3.75 + $total_cache_read * 0.30) / 1000000" | bc)

echo "$(date '+%Y-%m-%d %H:%M') | session=$session_id | in=$total_input out=$total_output cache_write=$total_cache_write cache_read=$total_cache_read | ~\$$cost" \
  >> ~/.claude/token-usage.log
