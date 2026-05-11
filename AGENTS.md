# ai-plugins

Plugins for Claude Code and Codex CLI, plus a native macOS token usage widget.

## Repo structure

```
ai-plugins/
├── claude/                   # Claude Code plugin
│   ├── .claude-plugin/plugin.json
│   └── hooks/
│       ├── hooks.json            # Hook wiring (Stop, UserPromptSubmit, PreCompact, PostCompact)
│       ├── track-tokens.sh       # Appends incremental JSONL entry to ~/.claude/token-usage/usage.jsonl
│       ├── statusline.sh         # Live token/cost statusline for Claude Code
│       ├── git-intent.sh         # Shorthand commit/push from UserPromptSubmit
│       ├── pre-compact.sh        # Snapshot context before compaction
│       ├── post-compact.sh       # Post-compaction placeholder
│       ├── migrate-token-log.sh  # One-time migration from old .log → .jsonl format (Python)
│       └── backfill-projects.sh  # Backfill project names from session transcripts (Python)
├── codex/                    # Codex CLI plugin
│   ├── .codex-plugin/plugin.json
│   ├── hooks.json
│   └── scripts/git-intent.sh
└── token-usage-app/          # Native macOS SwiftUI widget
    ├── build.sh              # Build script (uses swiftc directly — SPM broken on macOS 26 beta)
    └── Sources/TokenUsageApp/
        ├── App/TokenUsageApp.swift      # NSPanel floating widget, SMAppService login item
        ├── Models/UsageEntry.swift      # Decodable JSONL row
        ├── Models/TimeRange.swift       # TimeRangeKind + TimeWindow
        ├── Services/UsageStore.swift    # @MainActor store, file watcher
        ├── Services/FileWatcher.swift   # DispatchSource tail watcher
        └── Views/                       # ContentView, BarChartView, NavigationBar
```

## Token usage log

Written by `claude/hooks/track-tokens.sh` on every `Stop` event.

**Location:** `~/.claude/token-usage/usage.jsonl`
**State file:** `~/.claude/token-usage/state.json` (per-session cumulative totals for delta computation)

Each entry is one JSON line:
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

## Token usage widget

Native macOS floating panel built with SwiftUI + Swift Charts.

**Build & run:**
```bash
cd token-usage-app
./build.sh       # compile
./build.sh run   # compile + open
```

> SPM (`swift build`) is broken on macOS 26 beta — `build.sh` uses `swiftc` directly.

**Key behaviours:**
- Floats at bottom-right corner, always on top, shows on all spaces.
- Day = 7 daily bars, Week = 5 weekly bars, Month = 5 monthly bars.
- Drag chart left/right to slide the time window.
- Tap a bar to show its cost in the footer; tap again to deselect.
- File-watches `usage.jsonl` — updates live without restart.
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

## Updating the plugin after hook changes

The marketplace sparse clone does not auto-pull on reinstall:
```bash
git -C ~/.claude/plugins/marketplaces/ai-plugins pull
claude plugins uninstall claude-assistant@ai-plugins
claude plugins install claude-assistant@ai-plugins
```

## One-time utilities

| Script | Purpose |
|--------|---------|
| `claude/hooks/migrate-token-log.sh` | Convert old `token-usage.log` (pipe-delimited) to `usage.jsonl` |
| `claude/hooks/backfill-projects.sh` | Patch `project: "unknown"` entries using session transcript `cwd` |
