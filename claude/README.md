# claude-assistant

A Claude Code plugin providing token usage tracking, a live statusline, compaction analysis, and git shortcut commands.

## Features

### 1. Token Usage Log

**Script:** [`hooks/track-tokens.sh`](hooks/track-tokens.sh)
**Hook:** `Stop`

Appends a cost summary to `~/.claude/token-usage.log` at the end of every session.

```text
2026-05-04 17:37 | session=7e00a09e | in=37 out=4278 cache_write=31058 cache_read=293471 | ~$0.2687
```

Fields: date/time, session ID, input tokens, output tokens, cache write tokens, cache read tokens, estimated cost in USD.

Cost rates used for `claude-sonnet-4-6`:

| Token type | Rate per million |
|---|---|
| Input | $3.00 |
| Output | $15.00 |
| Cache write | $3.75 |
| Cache read | $0.30 |

### 2. Live Statusline

**Script:** [`hooks/statusline.sh`](hooks/statusline.sh)
**Config:** `statusLine` in `~/.claude/settings.json`

Displays a colour-coded statusline after each response showing real-time token and cost metrics.

```text
[claude-sonnet-4-6] in:37(330529) out:4278 cache(r/w):293471/31058 ctx:0% cost:$0.2687
```

The statusline must be wired manually in `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "/path/to/claude/hooks/statusline.sh"
}
```

### 3. Compaction Analysis

**Scripts:** [`hooks/pre-compact.sh`](hooks/pre-compact.sh), [`hooks/post-compact.sh`](hooks/post-compact.sh)
**Hooks:** `PreCompact`, `PostCompact`

Measures how many tokens were freed by a compaction and surfaces the result in the statusline.

The current implementation snapshots the latest context usage before compaction, then computes the delta in the next `Stop` hook using `~/.claude/compaction/*.json` state files.

### 4. Git Intent Shortcuts

**Script:** [`hooks/git-intent.sh`](hooks/git-intent.sh)
**Hook:** `UserPromptSubmit`

Intercepts short commit/push prompts, runs the corresponding git commands directly, and suppresses Claude inference.

Recognised prompt patterns are case-insensitive:

| Prompt | Behaviour |
|---|---|
| `Commit` | `git add -A` + `git commit` |
| `Push` | `git push` |
| `Commit and push` | commit then push |
| `Commit, push` | commit then push |
| `Commit, don't push` | commit only |
| `Commit, no push` | commit only |

Commit messages are generated from `git diff --staged --stat`, with `wip` as a fallback.

## File Structure

```text
claude/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
└── hooks/
    ├── hooks.json
    ├── git-intent.sh
    ├── post-compact.sh
    ├── pre-compact.sh
    ├── statusline.sh
    └── track-tokens.sh
```
