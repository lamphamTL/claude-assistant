#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "?"')
in_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
out_tok=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
cache_r=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_w=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_fmt=$(printf "%.4f" "$cost")

total_in=$((in_tok + cache_r + cache_w))

RESET='\033[0m'
BOLD='\033[1m'
WHITE='\033[37m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RED='\033[31m'
BLUE='\033[34m'

if [ "$ctx_pct" -ge 80 ]; then ctx_color=$RED
elif [ "$ctx_pct" -ge 50 ]; then ctx_color=$YELLOW
else ctx_color=$GREEN
fi

cost_int=$(echo "$cost * 100" | bc | cut -d. -f1)
if [ "$cost_int" -ge 50 ]; then cost_color=$RED
elif [ "$cost_int" -ge 10 ]; then cost_color=$YELLOW
else cost_color=$GREEN
fi

printf "${BOLD}${CYAN}[${model}]${RESET} "
printf "${BLUE}in${RESET}:${WHITE}${in_tok}${RESET}(${WHITE}${total_in}${RESET}) "
printf "${MAGENTA}out${RESET}:${WHITE}${out_tok}${RESET} "
printf "${CYAN}cache(r/w)${RESET}:${WHITE}${cache_r}/${cache_w}${RESET} "
printf "${ctx_color}ctx${RESET}:${WHITE}${ctx_pct}%%${RESET} "
printf "${cost_color}cost${RESET}:${WHITE}\$${cost_fmt}${RESET}\n"
