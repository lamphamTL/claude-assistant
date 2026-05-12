#!/usr/bin/env python3
import json
import os
import re
import shlex
import subprocess
import sys
import tomllib


def load_config(cwd, app_home):
    rules = []
    for path in [os.path.join(cwd, "static-dispatch.toml"),
                 os.path.join(app_home, "static-dispatch.toml")]:
        if os.path.isfile(path):
            with open(path, "rb") as f:
                rules += tomllib.load(f).get("rule", [])
    return rules


def dispatch(prompt, rules, cwd):
    for rule in rules:
        if re.search(rule["pattern"], prompt, re.IGNORECASE):
            script = f"cd {shlex.quote(cwd)} && {rule['command']}"
            subprocess.Popen(
                ["osascript", "-e",
                 f'tell application "Terminal" to do script {shlex.quote(script)}'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return f"Running in Terminal: {rule['command']}"
    return None


data   = json.loads(sys.stdin.read())
prompt = (data.get("prompt") or "").strip()
cwd    = data.get("cwd") or os.getcwd()

rules = load_config(cwd, os.path.expanduser("~/.claude"))
if not rules:
    sys.exit(0)

output = dispatch(prompt, rules, cwd)
if output is None:
    sys.exit(0)

print(json.dumps({"decision": "block", "reason": output}))
