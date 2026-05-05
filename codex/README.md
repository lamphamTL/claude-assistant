# codex-assistant

A Codex plugin providing git intent shortcuts.

## Features

### Git Intent Shortcuts

**Script:** [`hooks/git-intent.sh`](hooks/git-intent.sh)
**Hook:** `UserPromptSubmit`

Intercepts short commit/push prompts and runs the corresponding git commands directly.

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
codex/
├── .codex-plugin/
│   └── plugin.json
└── hooks/
    ├── hooks.json
    └── git-intent.sh
```
