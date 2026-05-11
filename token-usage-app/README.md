# Token Usage App

A native macOS floating widget that visualises Claude Code and Codex token costs over time, reading live from both `~/.claude/token-usage/usage.jsonl` and `~/.codex/token-usage/usage.jsonl`.

![Token Usage App screenshot](resources/Screenshot%202026-05-09%20at%2000.50.25.png)

## Features

- **Bar chart** of cost (USD) per day, week, or month
- **Source picker** — filter between All, Claude, and Codex usage
- **Day / Week / Month** range selector — 7 daily bars, 5 weekly bars, 5 monthly bars
- **Prev / Next arrows** to navigate through time; "Now" button to jump back to the present
- **Per-project filter** — breakdown by repo/working directory, scoped to the selected source
- **Tap a bar** to pin its cost in the footer; tap again to deselect
- **Live updates** — file-watches both `usage.jsonl` files and refreshes within ~1 s
- **Floating panel** — always on top of other windows, shows on all Spaces and fullscreen apps
- **Draggable** — click and drag from any empty area to reposition
- **Login item** — registers itself at first launch via `SMAppService`; appears in System Settings → General → Login Items

## Requirements

- macOS 14 or later (runs on macOS 26 Tahoe beta)
- Claude Code with `claude-assistant@ai-plugins` installed — writes `~/.claude/token-usage/usage.jsonl`
- Codex with `codex-assistant@ai-plugins` installed — writes `~/.codex/token-usage/usage.jsonl`

Both plugins are optional — the widget shows data for whichever logs exist.

## Build & run

```bash
cd token-usage-app
./build.sh        # compile only
./build.sh run    # compile and launch
```

> **Note:** Swift Package Manager (`swift build`) has a broken ManifestAPI arm64 slice on macOS 26 beta. `build.sh` calls `swiftc` directly to work around this.

## Data sources

### Claude (`~/.claude/token-usage/usage.jsonl`)

Written by the `track-tokens.sh` Stop hook in the Claude Code plugin. Each line:

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

### Codex (`~/.codex/token-usage/usage.jsonl`)

Written by the `track-tokens.sh` Stop hook in the Codex plugin. Token data is sourced from `token_count` events in the Codex session transcript. Each line:

```json
{
  "ts": "2026-05-08T10:00:00Z",
  "session_id": "uuid",
  "model": "gpt-5.5",
  "project": "ai-plugins",
  "tokens": { "input": 45, "output": 1823, "cache_read": 112074, "reasoning": 342 },
  "cost_usd": 0.062100
}
```

Values are incremental deltas per assistant turn, not cumulative session totals.
