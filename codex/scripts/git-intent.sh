#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
prompt=$(echo "$input" | jq -r '.prompt // empty' | xargs | tr '[:upper:]' '[:lower:]')

# Match short commit/push intent prompts only.
if ! echo "$prompt" | grep -qiE "^(commit|push|commit[,.]?\s+(and\s+)?(push|don'?t push|no push))[.!]?$"; then
  exit 0
fi

if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  cd "$cwd" || exit 0
fi

do_commit=false
do_push=false

echo "$prompt" | grep -qi 'commit' && do_commit=true
echo "$prompt" | grep -qi 'push' && do_push=true

# "don't push" / "no push" overrides push to false.
echo "$prompt" | grep -qiE "(don'?t|no)\s+push" && do_push=false

output=""

append_output() {
  if [ -n "$1" ]; then
    output="${output}${1}
"
  fi
}

if $do_commit; then
  add_out=$(git add -A 2>&1)
  add_status=$?
  append_output "$add_out"

  if [ "$add_status" -eq 0 ]; then
    msg=$(git diff --staged --stat 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//')
    [ -z "$msg" ] && msg="wip"
    commit_out=$(git commit -m "$msg" 2>&1)
    append_output "$commit_out"
  fi
fi

if $do_push; then
  push_out=$(git push 2>&1)
  append_output "$push_out"
fi

[ -z "$output" ] && output="No git output."

message_json=$(printf "%s" "$output" | jq -Rs .)
printf '{"continue": false, "systemMessage": %s}\n' "$message_json"
