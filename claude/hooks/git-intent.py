#!/usr/bin/env python3
import json
import re
import subprocess
import sys

data   = json.loads(sys.stdin.read())
prompt = (data.get("prompt") or "").strip().lower()

if not re.match(
    r"^(commit|push|commit[,.]?\s+(and\s+)?(push|don'?t push|no push))[.!]?$",
    prompt,
):
    sys.exit(0)

do_commit = "commit" in prompt
do_push   = "push"   in prompt
if re.search(r"(don'?t|no)\s+push", prompt):
    do_push = False

output_parts = []

if do_commit:
    subprocess.run(["git", "add", "-A"], capture_output=True)
    stat = subprocess.run(
        ["git", "diff", "--staged", "--stat"],
        capture_output=True, text=True,
    )
    lines = [l for l in stat.stdout.splitlines() if l.strip()]
    msg   = lines[-1].strip() if lines else "wip"
    commit = subprocess.run(
        ["git", "commit", "-m", msg],
        capture_output=True, text=True,
    )
    output_parts.append((commit.stdout + commit.stderr).strip())

if do_push:
    push = subprocess.run(["git", "push"], capture_output=True, text=True)
    output_parts.append((push.stdout + push.stderr).strip())

reason = " ".join(output_parts).replace('"', "'")
print(json.dumps({"decision": "block", "reason": reason}))
