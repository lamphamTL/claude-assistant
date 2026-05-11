#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
model=$(echo "$input" | jq -r '.model // "unknown"')

# ── Find transcript if not provided ──────────────────────────────────────────
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  today_dir="$HOME/.codex/sessions/$(date +%Y/%m/%d)"
  if [ -d "$today_dir" ]; then
    transcript=$(grep -rl "\"$session_id\"" "$today_dir" 2>/dev/null | head -1)
  fi
fi

[ -z "$transcript" ] || [ ! -f "$transcript" ] && exit 0

# ── Read session-total token_count from transcript ────────────────────────────
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

in_tok=$(echo "$last_count" | jq '.input_tokens // 0')
out_tok=$(echo "$last_count" | jq '.output_tokens // 0')
cached=$(echo "$last_count" | jq '.cached_input_tokens // 0')
reasoning=$(echo "$last_count" | jq '.reasoning_output_tokens // 0')

RESET='\033[0m'
BOLD='\033[1m'
WHITE='\033[37m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RED='\033[31m'
BLUE='\033[34m'

# Credits + cost (source: help.openai.com/en/articles/20001106-codex-rate-card)
# credits/M tokens; reasoning at output rate; 1 credit = $0.04
credits_and_cost=$(awk -v m="$model" -v i="$in_tok" -v o="$out_tok" -v c="$cached" -v r="$reasoning" '
BEGIN {
  if      (m == "gpt-5.5")        { ri=125;   ro=750;  rc=12.50  }
  else if (m == "gpt-5.4")        { ri=62.50; ro=375;  rc=6.25   }
  else if (m == "gpt-5.4-mini")   { ri=18.75; ro=113;  rc=1.875  }
  else if (m == "gpt-5.3-codex")  { ri=43.75; ro=350;  rc=4.375  }
  else if (m == "gpt-5.2")        { ri=43.75; ro=350;  rc=4.375  }
  else                            { ri=62.50; ro=375;  rc=6.25   }
  cr = (i*ri + (o+r)*ro + c*rc) / 1000000
  printf "%.2f %.4f", cr, cr * 0.04
}')
credits=$(echo "$credits_and_cost" | awk '{print $1}')
cost=$(echo "$credits_and_cost" | awk '{print $2}')

cost_int=$(echo "$cost * 100" | bc | cut -d. -f1)
if [ "$cost_int" -ge 50 ]; then cost_color=$RED
elif [ "$cost_int" -ge 10 ]; then cost_color=$YELLOW
else cost_color=$GREEN
fi

printf "${BOLD}${CYAN}[${model}]${RESET} "
printf "${BLUE}in${RESET}:${WHITE}${in_tok}${RESET} "
printf "${MAGENTA}out${RESET}:${WHITE}${out_tok}${RESET} "
printf "${CYAN}cache${RESET}:${WHITE}${cached}${RESET} "
printf "${YELLOW}reason${RESET}:${WHITE}${reasoning}${RESET} "
printf "${cost_color}credits${RESET}:${WHITE}${credits}${RESET} "
printf "${cost_color}cost${RESET}:${WHITE}\$${cost}${RESET}\n"
