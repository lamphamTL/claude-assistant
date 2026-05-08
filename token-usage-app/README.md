# Token Usage App

A native macOS floating widget that visualises Claude Code token costs over time, reading live from `~/.claude/token-usage/usage.jsonl`.

![Token Usage App screenshot](resources/Screenshot%202026-05-09%20at%2000.50.25.png)

## Features

- **Bar chart** of cost (USD) per day, week, or month
- **Day / Week / Month** range selector — 7 daily bars, 5 weekly bars, 5 monthly bars
- **Prev / Next arrows** to navigate through time; "Now" button to jump back to the present
- **Per-project filter** — breakdown by repo/working directory
- **Tap a bar** to pin its cost in the footer; tap again to deselect
- **Live updates** — file-watches `usage.jsonl` and refreshes the chart within ~1 s when a new session is logged
- **Floating panel** — always on top of other windows, shows on all Spaces and fullscreen apps
- **Draggable** — click and drag from any empty area to reposition
- **Login item** — registers itself at first launch via `SMAppService`; appears in System Settings → General → Login Items

## Requirements

- macOS 14 or later (runs on macOS 26 Tahoe beta)
- Claude Code with the `claude-assistant@ai-plugins` plugin installed (writes `usage.jsonl`)

## Build & run

```bash
cd token-usage-app
./build.sh        # compile only
./build.sh run    # compile and launch
```

> **Note:** Swift Package Manager (`swift build`) has a broken ManifestAPI arm64 slice on macOS 26 beta. `build.sh` calls `swiftc` directly to work around this.

## Data source

The widget reads `~/.claude/token-usage/usage.jsonl` — an append-only file written by the `track-tokens.sh` Stop hook in the Claude Code plugin. Each line is:

```json
{
  "ts": "2026-05-08T10:00:00Z",
  "session_id": "uuid",
  "model": "claude-sonnet-4-6",
  "project": "ai-plugins",
  "tokens": { "input": 45, "output": 1823, "cache_write": 8420, "cache_read": 112074 },
  "cost_usd": 0.048312
}
```

Values are incremental deltas per assistant turn, not cumulative session totals.

