#!/usr/bin/env python3
"""
Backfill project paths in ~/.claude/token-usage/usage.jsonl.

For entries where project == "unknown", finds the session transcript in
~/.claude/projects/*/<session_id>.jsonl and extracts the `cwd` field.
Rewrites usage.jsonl in-place; creates a .bak backup first.
"""
import json
import sys
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude/projects"
USAGE_JSONL  = Path.home() / ".claude/token-usage/usage.jsonl"

# ── Build session → cwd map from all transcripts ──────────────────────────────
print("Scanning transcripts…")
session_cwd: dict[str, str] = {}

for transcript in PROJECTS_DIR.glob("*/*.jsonl"):
    session_id = transcript.stem
    if session_id in session_cwd:
        continue
    try:
        for raw in transcript.open():
            raw = raw.strip()
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                continue
            cwd = obj.get("cwd")
            if cwd:
                session_cwd[session_id] = Path(cwd).name
                break
    except OSError:
        continue

print(f"Found {len(session_cwd)} sessions with cwd info.")

# ── Patch usage.jsonl ─────────────────────────────────────────────────────────
if not USAGE_JSONL.exists():
    print(f"No {USAGE_JSONL} found.")
    sys.exit(1)

lines = USAGE_JSONL.read_text().splitlines()
patched = 0
result: list[str] = []

for raw in lines:
    raw = raw.strip()
    if not raw:
        continue
    try:
        entry = json.loads(raw)
    except json.JSONDecodeError:
        result.append(raw)
        continue

    if entry.get("project") == "unknown":
        sid = entry.get("session_id", "")
        cwd = session_cwd.get(sid)
        if cwd:
            entry["project"] = cwd
            patched += 1

    result.append(json.dumps(entry))

# Backup then overwrite
backup = USAGE_JSONL.with_suffix(".jsonl.bak")
USAGE_JSONL.rename(backup)
USAGE_JSONL.write_text("\n".join(result) + "\n")

print(f"Patched {patched} entries. Backup at {backup}")
