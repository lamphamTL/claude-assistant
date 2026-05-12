# ai-plugins

Plugins for Claude Code and Codex CLI, plus a native macOS token usage widget.

## Repo structure

```
ai-plugins/
├── claude/                   # Claude Code plugin
│   ├── .claude-plugin/plugin.json
│   └── hooks/
│       ├── hooks.json            # Hook wiring (Stop, UserPromptSubmit, PreCompact, PostCompact)
│       ├── track-tokens.py       # Appends incremental JSONL entry to ~/.claude/token-usage/usage.jsonl
│       ├── statusline.py         # Live token/cost statusline for Claude Code
│       ├── static-dispatch.py    # Dispatch UserPromptSubmit prompts via static-scripts.toml rules
│       ├── pre-compact.py        # Snapshot context before compaction
│       ├── post-compact.py       # Post-compaction placeholder
│       ├── migrate-token-log.py  # One-time migration from old .log → .jsonl format
│       └── backfill-projects.py  # Backfill project names from session transcripts
├── codex/                    # Codex CLI plugin
│   ├── .codex-plugin/plugin.json
│   ├── hooks.json                # Hook wiring (Stop, UserPromptSubmit)
│   └── scripts/
│       ├── static-dispatch.py    # Dispatch UserPromptSubmit prompts via static-scripts.toml rules
│       ├── track-tokens.py       # Appends incremental JSONL entry to ~/.codex/token-usage/usage.jsonl
│       └── statusline.py         # Session token/cost summary printed after each turn
└── token-usage-app/          # Native macOS SwiftUI widget
    ├── build.sh              # Build script (uses swiftc directly — SPM broken on macOS 26 beta)
    ├── resources/            # Screenshots and assets
    └── Sources/TokenUsageApp/
        ├── App/TokenUsageApp.swift      # NSPanel floating widget, SMAppService login item
        ├── Models/UsageEntry.swift      # Decodable JSONL row
        ├── Models/TimeRange.swift       # TimeRangeKind + TimeWindow
        ├── Services/UsageStore.swift    # @MainActor store, dual file watcher (Claude + Codex)
        ├── Services/FileWatcher.swift   # DispatchSource tail watcher
        └── Views/                       # ContentView, BarChartView, NavigationBar
```

## Token usage logs

### Claude

Written by `claude/hooks/track-tokens.py` on every `Stop` event.

**Location:** `~/.claude/token-usage/usage.jsonl`
**State file:** `~/.claude/token-usage/state.json` (per-session cumulative totals for delta computation)

```json
{
  "ts": "2026-05-07T10:00:00Z",
  "session_id": "uuid",
  "model": "claude-sonnet-4-6",
  "project": "ai-plugins",
  "tokens": { "input": 45, "output": 1823, "cache_write": 8420, "cache_read": 112074 },
  "cost_usd": 0.048312
}
```

- `project` is the **basename** of `cwd`, with worktree paths (`/.claude/worktrees/<name>`) resolved to the parent project name.
- Values are **incremental deltas** per Stop event, not cumulative session totals.
- Cost rates: input $3/M, output $15/M, cache_write $3.75/M, cache_read $0.30/M (claude-sonnet-4-6).

### Codex

Written by `codex/scripts/track-tokens.py` on every `Stop` event.

**Location:** `~/.codex/token-usage/usage.jsonl`
**State file:** `~/.codex/token-usage/state.json` (per-session cumulative totals for delta computation)

```json
{
  "ts": "2026-05-07T10:00:00Z",
  "session_id": "uuid",
  "model": "gpt-5.5",
  "project": "ai-plugins",
  "tokens": { "input": 45, "output": 1823, "cache_read": 112074, "reasoning": 342 },
  "cost_usd": 0.062100
}
```

- Token data comes from `token_count` events in the session transcript JSONL (`~/.codex/sessions/`).
- Reasoning tokens billed at output rate.
- Cost rates per model (USD/million): see `codex/scripts/track-tokens.py`.

## Token usage widget

Native macOS floating panel built with SwiftUI + Swift Charts. Reads from both Claude and Codex logs.

**Build & run:**
```bash
cd token-usage-app
./build.sh       # compile
./build.sh run   # compile + open
```

> SPM (`swift build`) is broken on macOS 26 beta — `build.sh` uses `swiftc` directly.

**Key behaviours:**
- Floats at bottom-right corner, always on top, shows on all spaces.
- Source picker: All / Claude / Codex — filters chart and project list.
- Day = 7 daily bars, Week = 5 weekly bars, Month = 5 monthly bars.
- Drag chart left/right to slide the time window.
- Tap a bar to show its cost in the footer; tap again to deselect.
- File-watches both `usage.jsonl` files — updates live without restart.
- Registers as a login item via `SMAppService` on first launch.

## Plugin installation

**Claude Code:**
```bash
claude plugin marketplace add lamphamTL/ai-plugins --sparse .claude-plugin claude
claude plugin install claude-assistant@ai-plugins
```

**Codex:**
```bash
codex plugin marketplace add lamphamTL/ai-plugins
```

## Updating plugins after hook changes

The marketplace sparse clone does not auto-pull on reinstall.

**Claude Code:**
```bash
git -C ~/.claude/plugins/marketplaces/ai-plugins pull
claude plugins uninstall claude-assistant@ai-plugins
claude plugins install claude-assistant@ai-plugins
```

**Codex:**
```bash
codex plugin marketplace upgrade ai-plugins
```

## One-time utilities

| Script | Purpose |
|--------|---------|
| `claude/hooks/migrate-token-log.py` | Convert old `token-usage.log` (pipe-delimited) to `usage.jsonl` |
| `claude/hooks/backfill-projects.py` | Patch `project: "unknown"` entries using session transcript `cwd` |
