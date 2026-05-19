# codex-assistant

A Codex plugin providing token usage tracking, a session cost statusline, and configurable prompt dispatch.

## Features

### 1. Token Usage Log

**Script:** [`scripts/track-tokens.py`](scripts/track-tokens.py)
**Hook:** `Stop`

Appends an incremental JSONL entry to `~/.codex/token-usage/usage.jsonl` at the end of every turn.
`tokens.input` stores fresh non-cached input only; cached input is stored separately as `tokens.cache_read`.

### 2. Session Statusline

**Script:** [`scripts/statusline.py`](scripts/statusline.py)
**Hook:** `Stop`

Prints a colour-coded cost summary to the console after each turn.

### 3. Prompt Dispatch

**Script:** [`scripts/static-dispatch.py`](scripts/static-dispatch.py)
**Hook:** `UserPromptSubmit`

Intercepts prompts matching regex rules defined in `static-dispatch.toml`, runs the corresponding shell command, and suppresses Codex inference.

Config is loaded from the first file found (project takes precedence):
1. `{cwd}/static-dispatch.toml`
2. `~/.codex/static-dispatch.toml`

Example config:

```toml
# matches: "commit and push", "commit, push"
[[rule]]
pattern = "^commit[,.]?\\s+(and\\s+)?push[.!]?$"
command = "git add -A && git diff --staged --stat | tail -1 | xargs -I{} git commit -m '{}' && git push"

# matches: "commit", "commit.", "commit!"
[[rule]]
pattern = "^commit[.!]?$"
command = "git add -A && git diff --staged --stat | tail -1 | xargs -I{} git commit -m '{}'"

# matches: "push", "push.", "push!"
[[rule]]
pattern = "^push[.!]?$"
command = "git push"
```

Rules are matched top-to-bottom; first match wins. The matched prompt is available as `INTENT_PROMPT` env var in the command.

## File Structure

```text
codex/
├── .codex-plugin/
│   └── plugin.json
├── hooks.json
└── scripts/
    ├── static-dispatch.py
    ├── track-tokens.py
    └── statusline.py
```
