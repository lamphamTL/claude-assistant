#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys

data   = json.loads(sys.stdin.read())
cwd    = data.get("cwd") or ""
prompt = (data.get("prompt") or "").strip().lower()

if not re.match(
    r"^(commit|push|commit[,.]?\s+(and\s+)?(push|don'?t push|no push))[.!]?$",
    prompt,
):
    sys.exit(0)

if cwd and os.path.isdir(cwd):
    os.chdir(cwd)

do_commit = "commit" in prompt
do_push   = "push"   in prompt
if re.search(r"(don'?t|no)\s+push", prompt):
    do_push = False

output_parts = []

if do_commit:
    add = subprocess.run(["git", "add", "-A"], capture_output=True, text=True)
    if add.returncode == 0:
        stat = subprocess.run(
            ["git", "diff", "--staged", "--stat"],
            capture_output=True, text=True,
        )
        lines = [l.strip() for l in stat.stdout.splitlines() if l.strip()]
        msg   = lines[-1] if lines else "wip"
        commit = subprocess.run(
            ["git", "commit", "-m", msg],
            capture_output=True, text=True,
        )
        output_parts.append((commit.stdout + commit.stderr).strip())
    else:
        output_parts.append((add.stdout + add.stderr).strip())

if do_push:
    push = subprocess.run(["git", "push"], capture_output=True, text=True)
    output_parts.append((push.stdout + push.stderr).strip())

if not output_parts:
    output_parts = ["No git output."]

message = "\n".join(p for p in output_parts if p)
print(json.dumps({"continue": False, "systemMessage": message}))
