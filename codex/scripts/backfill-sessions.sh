#!/bin/bash
# Backfill ~/.codex/token-usage/usage.jsonl from existing session transcripts.
# Writes one entry per turn (token_count event) using last_token_usage delta
# and the event's own timestamp — correctly distributes multi-day sessions.
# Safe to re-run — skips entries already present by session_id:timestamp key.

mkdir -p ~/.codex/token-usage

python3 << 'EOF'
import json, os, glob
from pathlib import Path

USAGE_FILE = Path.home() / ".codex/token-usage/usage.jsonl"

# Credits per million tokens — source: help.openai.com/en/articles/20001106-codex-rate-card
# 1 credit = $0.04
RATES = {
    "gpt-5.5":        {"ri": 125,    "ro": 750,  "rc": 12.50},
    "gpt-5.4":        {"ri": 62.50,  "ro": 375,  "rc": 6.25},
    "gpt-5.4-mini":   {"ri": 18.75,  "ro": 113,  "rc": 1.875},
    "gpt-5.3-codex":  {"ri": 43.75,  "ro": 350,  "rc": 4.375},
    "gpt-5.2":        {"ri": 43.75,  "ro": 350,  "rc": 4.375},
}
DEFAULT_RATE = {"ri": 62.50, "ro": 375, "rc": 6.25}
CREDIT_TO_USD = 0.04

def compute(model, usage):
    r = RATES.get((model or "").lower(), DEFAULT_RATE)
    i  = usage.get("input_tokens", 0)
    o  = usage.get("output_tokens", 0)
    c  = usage.get("cached_input_tokens", 0)
    rs = usage.get("reasoning_output_tokens", 0)
    credits = (i * r["ri"] + (o + rs) * r["ro"] + c * r["rc"]) / 1_000_000
    return round(credits, 6), round(credits * CREDIT_TO_USD, 6)

def project_from_cwd(cwd):
    return os.path.basename(cwd.rstrip("/")) if cwd else "unknown"

def normalise_ts(ts):
    if not ts:
        return None
    ts = ts.replace("+00:00", "Z")
    if not ts.endswith("Z"):
        ts += "Z"
    return ts

def parse_turns(path):
    """Yield one dict per token_count event with non-null info."""
    session_id = None
    model = None
    cwd = None

    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    t = d.get("type")
                    p = d.get("payload", {})

                    if t == "session_meta":
                        session_id = p.get("id")
                        cwd = cwd or p.get("cwd")

                    elif t == "turn_context":
                        model = p.get("model") or model
                        cwd = cwd or p.get("cwd")

                    elif t == "event_msg" and p.get("type") == "token_count":
                        info = p.get("info")
                        if not info or not session_id:
                            continue
                        last = info.get("last_token_usage", {})
                        # Skip turns with no output (no real generation)
                        if last.get("output_tokens", 0) == 0:
                            continue
                        ts = normalise_ts(d.get("timestamp"))
                        if not ts:
                            continue
                        credits, cost = compute(model, last)
                        yield {
                            "ts":         ts,
                            "session_id": session_id,
                            "model":      model or "unknown",
                            "project":    project_from_cwd(cwd),
                            "tokens": {
                                "input":      last.get("input_tokens", 0),
                                "output":     last.get("output_tokens", 0),
                                "cache_read": last.get("cached_input_tokens", 0),
                                "reasoning":  last.get("reasoning_output_tokens", 0),
                            },
                            "credits":  credits,
                            "cost_usd": cost,
                        }
                except Exception:
                    pass
    except Exception:
        pass

# Load existing dedup keys: session_id:ts
existing = set()
if USAGE_FILE.exists():
    with open(USAGE_FILE, encoding="utf-8") as f:
        for line in f:
            try:
                e = json.loads(line)
                existing.add(f"{e['session_id']}:{e['ts']}")
            except Exception:
                pass

home = Path.home()
files = sorted(glob.glob(str(home / ".codex/sessions/**/*.jsonl"), recursive=True))
files += sorted(glob.glob(str(home / ".codex/archived_sessions/*.jsonl")))

added = skipped = no_turns = 0

with open(USAGE_FILE, "a", encoding="utf-8") as out:
    for path in files:
        turns = list(parse_turns(path))
        if not turns:
            no_turns += 1
            continue
        for entry in turns:
            key = f"{entry['session_id']}:{entry['ts']}"
            if key in existing:
                skipped += 1
                continue
            out.write(json.dumps(entry) + "\n")
            existing.add(key)
            added += 1

print(f"Done. added={added}  skipped={skipped}  no-turns={no_turns}")
EOF
