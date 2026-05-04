#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')

# Save context snapshot for compaction tracking
in_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_r=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_w=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
context_tokens=$((in_tok + cache_r + cache_w))

mkdir -p ~/.claude/compaction
echo "{\"session_id\": \"$session_id\", \"context_tokens\": $context_tokens}" > ~/.claude/compaction/last-stop.json

# If pre.json exists with matching session, compute compaction delta
pre_file=~/.claude/compaction/pre.json
if [ -f "$pre_file" ]; then
  pre_session=$(jq -r '.session_id // empty' "$pre_file")
  if [ "$pre_session" = "$session_id" ]; then
    tokens_before=$(jq -r '.tokens_before // 0' "$pre_file")
    reduced=$((tokens_before - context_tokens))
    echo "{\"session_id\": \"$session_id\", \"tokens_before\": $tokens_before, \"tokens_after\": $context_tokens, \"reduced\": $reduced}" \
      > ~/.claude/compaction/result.json
    rm -f "$pre_file"
  fi
fi

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
