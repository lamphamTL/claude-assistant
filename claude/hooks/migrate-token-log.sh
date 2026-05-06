#!/usr/bin/env python3
"""
One-time migration: convert ~/.claude/token-usage.log to ~/.claude/token-usage.jsonl
Old format: YYYY-MM-DD HH:MM | session=<uuid> | in=N out=N cache_write=N cache_read=N | ~$N
New format: JSONL with incremental deltas per session stop

Limitation: old log has no model/project fields — set to "unknown".
Old values are cumulative per session; converts to incremental deltas.
"""
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

LOG = Path.home() / ".claude/token-usage.log"
JSONL = Path.home() / ".claude/token-usage/usage.jsonl"

if not LOG.exists():
    print(f"No {LOG} found, nothing to migrate.")
    sys.exit(0)

if JSONL.exists():
    print(f"Existing {JSONL} found — skipping migration to avoid duplicates.")
    print(f"Remove {JSONL} first if you want to re-run migration.")
    sys.exit(0)

prev = {}  # session_id -> {"input", "output", "cache_write", "cache_read"}
entries = []

for line in LOG.read_text().splitlines():
    line = line.strip()
    if not line:
        continue
    parts = [p.strip() for p in line.split("|")]
    if len(parts) < 3:
        continue

    ts_raw = parts[0]
    session_id = parts[1].replace("session=", "").strip()
    tok_part = parts[2]

    def extract(key):
        m = re.search(rf"{key}=(\d+)", tok_part)
        return int(m.group(1)) if m else 0

    total = {
        "input": extract("in"),
        "output": extract("out"),
        "cache_write": extract("cache_write"),
        "cache_read": extract("cache_read"),
    }

    p = prev.get(session_id, {"input": 0, "output": 0, "cache_write": 0, "cache_read": 0})
    delta = {k: total[k] - p[k] for k in total}
    prev[session_id] = total

    if delta["input"] == 0 and delta["output"] == 0:
        continue

    # Parse timestamp (assume local time, store as UTC)
    try:
        dt = datetime.strptime(ts_raw, "%Y-%m-%d %H:%M")
        ts = dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        ts = ts_raw.replace(" ", "T") + ":00Z"

    cost = round(
        (delta["input"] * 3 + delta["output"] * 15
         + delta["cache_write"] * 3.75 + delta["cache_read"] * 0.30) / 1_000_000,
        6,
    )

    entries.append({
        "ts": ts,
        "session_id": session_id,
        "model": "unknown",
        "project": "unknown",
        "tokens": {
            "input": delta["input"],
            "output": delta["output"],
            "cache_write": delta["cache_write"],
            "cache_read": delta["cache_read"],
        },
        "cost_usd": cost,
    })

JSONL.write_text("\n".join(json.dumps(e) for e in entries) + "\n")
print(f"Migrated {len(entries)} entries to {JSONL}")
