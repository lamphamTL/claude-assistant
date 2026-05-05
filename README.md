# ai-plugins

This repository contains two independent assistant plugin packages:

- [`claude/`](claude/) is the Claude Code plugin.
- [`codex/`](codex/) is the Codex plugin.

The two plugin folders do not share hooks or scripts. Behavior that exists in both products is intentionally duplicated so each integration can use the hook protocol and install metadata expected by that host.

## Repository Layout

```text
ai-plugins/
├── .agents/
│   └── plugins/
│       └── marketplace.json
├── .claude-plugin/
│   └── marketplace.json
├── claude/
│   ├── README.md
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── hooks/
│       ├── hooks.json
│       ├── git-intent.sh
│       ├── post-compact.sh
│       ├── pre-compact.sh
│       ├── statusline.sh
│       └── track-tokens.sh
└── codex/
    ├── README.md
    ├── .codex-plugin/
    │   └── plugin.json
    └── hooks/
        ├── git-intent.sh
        └── hooks.json
```

## Plugin Responsibilities

The Claude plugin keeps the existing Claude Code workflow helpers: token usage logging, live statusline, compaction analysis, and git intent shortcuts.

The Codex plugin currently contains the Codex version of the git intent shortcut hook. It handles short prompts like `commit`, `push`, and `commit and push` directly from `UserPromptSubmit`.

## Marketplace Installation

Claude installs from the repository-level Claude marketplace and only fetches the Claude plugin paths:

```bash
claude plugin marketplace add lamphamTL/ai-plugins --sparse .claude-plugin claude
claude plugin install claude-assistant@ai-plugins
```

Codex installs from the repository-level Codex marketplace:

```bash
codex plugin marketplace add lamphamTL/ai-plugins
```
