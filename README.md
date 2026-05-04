# claude-assistant

A Claude Code plugin providing token usage tracking, a live statusline, and git shortcut commands.

## Features

### 1. Token Usage Log

**Script:** [`hooks/track-tokens.sh`](hooks/track-tokens.sh)  
**Hook:** `Stop`

Appends a cost summary to `~/.claude/token-usage.log` at the end of every session.

```
2026-05-04 17:37 | session=7e00a09e | in=37 out=4278 cache_write=31058 cache_read=293471 | ~$0.2687
```

Fields: date/time, session ID, input tokens, output tokens, cache write tokens, cache read tokens, estimated cost (USD).

Cost rates used (claude-sonnet-4-6):
| Token type | Rate per million |
|---|---|
| Input | $3.00 |
| Output | $15.00 |
| Cache write | $3.75 |
| Cache read | $0.30 |

---

### 2. Live Statusline

**Script:** [`hooks/statusline.sh`](hooks/statusline.sh)  
**Config:** `statusLine` in `~/.claude/settings.json`

Displays a colour-coded statusline after each response showing real-time token and cost metrics.

```
[claude-sonnet-4-6] in:37(330529) out:4278 cache(r/w):293471/31058 ctx:0% cost:$0.2687
```

Colour thresholds:
- **Context window** — green < 50%, yellow 50–79%, red ≥ 80%
- **Cost** — green < $0.10, yellow $0.10–$0.49, red ≥ $0.50

> The statusline must be wired manually in `~/.claude/settings.json` as it is not supported by `hooks.json`:
> ```json
> "statusLine": {
>   "type": "command",
>   "command": "~/.claude/claude-assistant/hooks/statusline.sh"
> }
> ```

---

### 3. Git Intent Shortcuts

**Script:** [`hooks/git-intent.sh`](hooks/git-intent.sh)  
**Hook:** `UserPromptSubmit`

Intercepts short commit/push prompts, runs the corresponding git commands directly, and suppresses Claude inference entirely — no tokens spent.

Recognised prompt patterns (case-insensitive):

| Prompt | Behaviour |
|---|---|
| `Commit` | `git add -A` + `git commit` |
| `Push` | `git push` |
| `Commit and push` | commit then push |
| `Commit, push` | commit then push |
| `Commit, don't push` | commit only |
| `Commit, no push` | commit only |

Commit message is auto-generated from `git diff --staged --stat`. Falls back to `wip` if nothing is staged.

Prompts not matching these patterns pass through to Claude normally.

---

## Installation

### Via marketplace (after pushing to GitHub)

```
/plugin marketplace add github:lamp/claude-assistant
/plugin install claude-assistant@claude-assistant
```

Then add the statusline to `~/.claude/settings.json` manually (see above).

### Local development

The repo is pre-registered as a local marketplace in `~/.claude/plugins/known_marketplaces.json`. The symlink `~/.claude/claude-assistant → ~/Documents/Project/claude-assistant` makes hooks active immediately.

---

## File structure

```
claude-assistant/
├── .claude-plugin/
│   └── plugin.json        # Plugin metadata
├── hooks/
│   ├── hooks.json         # Hook event declarations
│   ├── git-intent.sh      # Git shortcut hook (UserPromptSubmit)
│   ├── track-tokens.sh    # Token log hook (Stop)
│   └── statusline.sh      # Live statusline renderer
└── marketplace.json       # Self-hostable marketplace entry
```
