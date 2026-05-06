#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')

# Project: check hook input cwd, then env vars
project=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$project" ] && project="${CWD:-${PWD:-unknown}}"

# ── Compaction tracking (unchanged) ──────────────────────────────────────────
in_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_r=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_w=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
context_tokens=$((in_tok + cache_r + cache_w))

mkdir -p ~/.claude/compaction
echo "{\"session_id\": \"$session_id\", \"context_tokens\": $context_tokens}" > ~/.claude/compaction/last-stop.json

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

# ── Accumulate cumulative session totals from transcript ──────────────────────
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

# ── Compute incremental delta since last Stop for this session ────────────────
mkdir -p ~/.claude/token-usage
state_file=~/.claude/token-usage/state.json
prev_input=0
prev_output=0
prev_cache_write=0
prev_cache_read=0

if [ -f "$state_file" ]; then
  prev=$(jq -r --arg sid "$session_id" '.[$sid] // empty' "$state_file" 2>/dev/null)
  if [ -n "$prev" ]; then
    prev_input=$(echo "$prev" | jq '.input // 0')
    prev_output=$(echo "$prev" | jq '.output // 0')
    prev_cache_write=$(echo "$prev" | jq '.cache_write // 0')
    prev_cache_read=$(echo "$prev" | jq '.cache_read // 0')
  fi
fi

delta_input=$((total_input - prev_input))
delta_output=$((total_output - prev_output))
delta_cache_write=$((total_cache_write - prev_cache_write))
delta_cache_read=$((total_cache_read - prev_cache_read))

# Nothing new to log
if [ "$delta_input" -eq 0 ] && [ "$delta_output" -eq 0 ]; then
  exit 0
fi

# ── Persist updated cumulative totals for this session ───────────────────────
new_state=$(jq -n \
  --arg sid "$session_id" \
  --argjson i "$total_input" --argjson o "$total_output" \
  --argjson cw "$total_cache_write" --argjson cr "$total_cache_read" \
  '{($sid): {input: $i, output: $o, cache_write: $cw, cache_read: $cr}}')

if [ -f "$state_file" ]; then
  tmp=$(mktemp)
  jq --argjson s "$new_state" '. * $s' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
else
  echo "$new_state" > "$state_file"
fi

# ── Cost (awk ensures valid JSON number with leading zero) ───────────────────
# Rates for claude-sonnet-4-6 (USD/million): input $3, output $15, cache_write $3.75, cache_read $0.30
cost=$(awk "BEGIN {printf \"%.6f\", ($delta_input * 3 + $delta_output * 15 + $delta_cache_write * 3.75 + $delta_cache_read * 0.30) / 1000000}")

# ── Append JSONL entry ────────────────────────────────────────────────────────
ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
jq -cn \
  --arg ts "$ts" \
  --arg sid "$session_id" \
  --arg model "$model" \
  --arg project "$project" \
  --argjson input "$delta_input" \
  --argjson output "$delta_output" \
  --argjson cache_write "$delta_cache_write" \
  --argjson cache_read "$delta_cache_read" \
  --argjson cost "$cost" \
  '{ts: $ts, session_id: $sid, model: $model, project: $project,
    tokens: {input: $input, output: $output, cache_write: $cache_write, cache_read: $cache_read},
    cost_usd: $cost}' \
  >> ~/.claude/token-usage/usage.jsonl
