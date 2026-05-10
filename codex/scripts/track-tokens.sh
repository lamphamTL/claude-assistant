#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
model=$(echo "$input" | jq -r '.model // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Project name: basename works for both regular and worktree paths
# (~/.codex/worktrees/<hash>/<project> → <project>)
project=$(basename "${cwd:-${PWD:-unknown}}")

# ── Find transcript if not provided ──────────────────────────────────────────
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  today_dir="$HOME/.codex/sessions/$(date +%Y/%m/%d)"
  if [ -d "$today_dir" ]; then
    transcript=$(grep -rl "\"$session_id\"" "$today_dir" 2>/dev/null | head -1)
  fi
fi

[ -z "$transcript" ] || [ ! -f "$transcript" ] && exit 0

# ── Read last token_count totals from transcript (Python for robustness) ─────
last_count=$(python3 - "$transcript" <<'EOF'
import sys, json
last = None
try:
    with open(sys.argv[1]) as f:
        for line in f:
            try:
                d = json.loads(line)
                p = d.get('payload', {})
                if d.get('type') == 'event_msg' and p.get('type') == 'token_count' and p.get('info') is not None:
                    last = p['info']['total_token_usage']
            except Exception:
                pass
except Exception:
    pass
if last:
    print(json.dumps(last))
EOF
)

[ -z "$last_count" ] && exit 0

total_input=$(echo "$last_count" | jq '.input_tokens // 0')
total_output=$(echo "$last_count" | jq '.output_tokens // 0')
total_cached=$(echo "$last_count" | jq '.cached_input_tokens // 0')
total_reasoning=$(echo "$last_count" | jq '.reasoning_output_tokens // 0')

# ── Compute incremental delta since last Stop for this session ────────────────
mkdir -p ~/.codex/token-usage
state_file=~/.codex/token-usage/state.json
prev_input=0
prev_output=0
prev_cached=0
prev_reasoning=0

if [ -f "$state_file" ]; then
  prev=$(jq -r --arg sid "$session_id" '.[$sid] // empty' "$state_file" 2>/dev/null)
  if [ -n "$prev" ]; then
    prev_input=$(echo "$prev" | jq '.input // 0')
    prev_output=$(echo "$prev" | jq '.output // 0')
    prev_cached=$(echo "$prev" | jq '.cached // 0')
    prev_reasoning=$(echo "$prev" | jq '.reasoning // 0')
  fi
fi

delta_input=$((total_input - prev_input))
delta_output=$((total_output - prev_output))
delta_cached=$((total_cached - prev_cached))
delta_reasoning=$((total_reasoning - prev_reasoning))

if [ "$delta_input" -eq 0 ] && [ "$delta_output" -eq 0 ]; then
  exit 0
fi

# ── Persist updated cumulative totals ────────────────────────────────────────
new_state=$(jq -n \
  --arg sid "$session_id" \
  --argjson i "$total_input" --argjson o "$total_output" \
  --argjson c "$total_cached" --argjson r "$total_reasoning" \
  '{($sid): {input: $i, output: $o, cached: $c, reasoning: $r}}')

if [ -f "$state_file" ]; then
  tmp=$(mktemp)
  jq --argjson s "$new_state" '. * $s' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
else
  echo "$new_state" > "$state_file"
fi

# ── Cost (reasoning billed at output rate) ────────────────────────────────────
# Rates USD/million tokens — source: developers.openai.com/api/docs/pricing
cost=$(awk -v m="$model" -v di="$delta_input" -v do_="$delta_output" \
          -v dc="$delta_cached" -v dr="$delta_reasoning" '
BEGIN {
  if      (m == "gpt-5.5")      { ri=5.00;  ro=30.00; rc=0.50  }
  else if (m == "gpt-5.4")      { ri=2.50;  ro=15.00; rc=0.25  }
  else if (m == "gpt-5.4-mini") { ri=0.75;  ro=4.50;  rc=0.075 }
  else if (m == "gpt-5.4-nano") { ri=0.20;  ro=1.25;  rc=0.02  }
  else                          { ri=2.50;  ro=15.00; rc=0.25  }
  printf "%.6f", (di*ri + (do_+dr)*ro + dc*rc) / 1000000
}')

# ── Append JSONL entry ────────────────────────────────────────────────────────
ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
jq -cn \
  --arg ts "$ts" \
  --arg sid "$session_id" \
  --arg model "$model" \
  --arg project "$project" \
  --argjson input "$delta_input" \
  --argjson output "$delta_output" \
  --argjson cache_read "$delta_cached" \
  --argjson reasoning "$delta_reasoning" \
  --argjson cost "$cost" \
  '{ts: $ts, session_id: $sid, model: $model, project: $project,
    tokens: {input: $input, output: $output, cache_read: $cache_read, reasoning: $reasoning},
    cost_usd: $cost}' \
  >> ~/.codex/token-usage/usage.jsonl
