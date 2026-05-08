# ai-plugins

Plugins for Claude Code and Codex CLI, plus a native macOS token usage widget.

- [`claude/`](claude/) — Claude Code plugin
- [`codex/`](codex/) — Codex CLI plugin
- [`token-usage-app/`](token-usage-app/) — macOS floating widget to visualise AI spend

## Repository Layout

```text
ai-plugins/
├── .agents/
│   └── plugins/marketplace.json
├── .claude-plugin/
│   └── marketplace.json
├── claude/
│   ├── .claude-plugin/plugin.json
│   └── hooks/
│       ├── hooks.json
│       ├── track-tokens.sh       # writes ~/.claude/token-usage/usage.jsonl
│       ├── statusline.sh         # live token/cost statusline
│       ├── git-intent.sh
│       ├── pre-compact.sh
│       ├── post-compact.sh
│       ├── migrate-token-log.sh  # one-time .log → .jsonl migration
│       └── backfill-projects.sh  # backfill project names from transcripts
├── codex/
│   ├── .codex-plugin/plugin.json
│   ├── hooks.json
│   └── scripts/git-intent.sh
└── token-usage-app/
    ├── README.md
    ├── build.sh                  # swiftc build script
    └── Sources/TokenUsageApp/
```

## Components

### Claude Code plugin

Token usage logging, live statusline, compaction tracking, git intent shortcuts.

Hooks fire on `Stop`, `UserPromptSubmit`, `PreCompact`, and `PostCompact`. Each `Stop` appends an incremental JSONL entry to `~/.claude/token-usage/usage.jsonl` with timestamp, session ID, model, project name, per-type token deltas, and cost in USD.

### Codex plugin

Git intent shortcut hook (`UserPromptSubmit`) — handles short prompts like `commit`, `push`, and `commit and push`.

### Token Usage App

Native macOS floating widget built with SwiftUI + Swift Charts. Reads `~/.claude/token-usage/usage.jsonl` and renders cost over time as a bar chart.

See [`token-usage-app/README.md`](token-usage-app/README.md) for details and build instructions.

## Marketplace Installation

**Claude Code:**
```bash
claude plugin marketplace add lamphamTL/ai-plugins --sparse .claude-plugin claude
claude plugin install claude-assistant@ai-plugins
```

**Codex:**
```bash
codex plugin marketplace add lamphamTL/ai-plugins
```

## Updating the Claude plugin after hook changes

The marketplace sparse clone doesn't auto-pull on reinstall:
```bash
git -C ~/.claude/plugins/marketplaces/ai-plugins pull
claude plugins uninstall claude-assistant@ai-plugins
claude plugins install claude-assistant@ai-plugins
```
