#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
model=$(echo "$input" | jq -r '.model // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Project name — handle Codex worktrees, Android worktrees, and junk paths
project=$(python3 - "${cwd:-${PWD:-}}" <<'PYEOF'
import sys, os
from pathlib import Path
cwd = sys.argv[1].rstrip('/') if len(sys.argv) > 1 else ''
if not cwd:
    print('unknown'); raise SystemExit
home = str(Path.home())
# Codex managed worktrees: ~/.codex/worktrees/<hash>/<project>
codex_wt = home + '/.codex/worktrees/'
if cwd.startswith(codex_wt):
    parts = cwd[len(codex_wt):].split('/', 1)
    print(parts[1] if len(parts) == 2 else 'unknown'); raise SystemExit
# Junk paths
if cwd == home or any(cwd.startswith(home + p) for p in ['/Library/', '/.codex', '/Documents/Codex/']):
    print('unknown'); raise SystemExit
# Android-style nested worktrees: <project>/worktree/<type>/<branch>
if '/worktree/' in cwd:
    print(os.path.basename(cwd[:cwd.index('/worktree/')])); raise SystemExit
# Android-style flat worktrees: <project>/worktree_<name>
base = os.path.basename(cwd)
if base.startswith('worktree_') or base.startswith('worktree-'):
    parent = os.path.dirname(cwd)
    print(os.path.basename(parent) if parent != home else 'unknown'); raise SystemExit
print(base if base else 'unknown')
PYEOF
)

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

# ── Credits + cost (source: help.openai.com/en/articles/20001106-codex-rate-card)
# credits/M tokens; reasoning billed at output rate; 1 credit = $0.04
credits_and_cost=$(awk -v m="$model" -v di="$delta_input" -v do_="$delta_output" \
                       -v dc="$delta_cached" -v dr="$delta_reasoning" '
BEGIN {
  if      (m == "gpt-5.5")        { ri=125;   ro=750;  rc=12.50  }
  else if (m == "gpt-5.4")        { ri=62.50; ro=375;  rc=6.25   }
  else if (m == "gpt-5.4-mini")   { ri=18.75; ro=113;  rc=1.875  }
  else if (m == "gpt-5.3-codex")  { ri=43.75; ro=350;  rc=4.375  }
  else if (m == "gpt-5.2")        { ri=43.75; ro=350;  rc=4.375  }
  else                            { ri=62.50; ro=375;  rc=6.25   }
  cr = (di*ri + (do_+dr)*ro + dc*rc) / 1000000
  printf "%.6f %.6f", cr, cr * 0.04
}')
credits=$(echo "$credits_and_cost" | awk '{print $1}')
cost=$(echo "$credits_and_cost" | awk '{print $2}')

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
  --argjson credits "$credits" \
  --argjson cost "$cost" \
  '{ts: $ts, session_id: $sid, model: $model, project: $project,
    tokens: {input: $input, output: $output, cache_read: $cache_read, reasoning: $reasoning},
    credits: $credits, cost_usd: $cost}' \
  >> ~/.codex/token-usage/usage.jsonl
