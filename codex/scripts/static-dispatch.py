#!/usr/bin/env python3
import json
import os
import re
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
            sys.stderr.write(f"Running: {rule['command']}\n")
            sys.stderr.flush()
            proc = subprocess.Popen(
                rule["command"], shell=True, cwd=cwd,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, env={**os.environ, "INTENT_PROMPT": prompt},
            )
            for line in proc.stdout:
                sys.stderr.write(line)
                sys.stderr.flush()
            proc.wait()
            return f"exited with code {proc.returncode}"
    return None


data   = json.loads(sys.stdin.read())
prompt = (data.get("prompt") or "").strip()
cwd    = data.get("cwd") or os.getcwd()

if os.path.isdir(cwd):
    os.chdir(cwd)

rules = load_config(cwd, os.path.expanduser("~/.codex"))
if not rules:
    sys.exit(0)

output = dispatch(prompt, rules, cwd)
if output is None:
    sys.exit(0)

print(json.dumps({"continue": False, "systemMessage": output}))
