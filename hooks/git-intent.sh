#!/bin/bash
input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // empty' | xargs | tr '[:upper:]' '[:lower:]')

# Match short commit/push intent prompts only
if ! echo "$prompt" | grep -qiE "^(commit|push|commit[,.]?\s+(and\s+)?(push|don'?t push|no push))[.!]?$"; then
  exit 0
fi

do_commit=false
do_push=false

echo "$prompt" | grep -qi 'commit' && do_commit=true
echo "$prompt" | grep -qi 'push' && do_push=true

# "don't push" / "no push" overrides push to false
echo "$prompt" | grep -qiE "(don'?t|no)\s+push" && do_push=false

output=""

if $do_commit; then
  git add -A
  msg=$(git diff --staged --stat 2>/dev/null | tail -1)
  [ -z "$msg" ] && msg="wip"
  commit_out=$(git commit -m "$msg" 2>&1)
  output="$output\n$commit_out"
fi

if $do_push; then
  push_out=$(git push 2>&1)
  output="$output\n$push_out"
fi

echo "{\"decision\": \"block\", \"reason\": \"$(echo -e "$output" | tr '"' "'" | tr '\n' ' ')\"}"
