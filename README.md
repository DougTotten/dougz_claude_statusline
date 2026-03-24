# Claude Code Statusline

A custom statusline script for [Claude Code](https://github.com/anthropics/claude-code) that displays rate limit usage, git branch state, active model, and context window usage.

## Files

| File | Destination |
|------|-------------|
| `statusline.sh` | `~/.claude/statusline.sh` |

## Setup

1. Copy `statusline.sh` to `~/.claude/`:

   ```bash
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Add the following to `~/.claude/settings.json`:

   ```json
   "statusLine": {
     "type": "command",
     "command": "bash ~/.claude/statusline.sh"
   }
   ```

## What it looks like

The statusline displays up to two lines at the bottom of the Claude Code interface.

**Line 1 — Rate limit usage** *(only shown when rate limit data is available):*

```
5h: 23%  resets 4:30pm  ·  7d: 61%  resets Sat 9:00am
```

- `5h` = rolling 5-hour usage percentage
- `7d` = rolling 7-day usage percentage
- Percentage color: green (< 50%) → yellow (50–79%) → red (≥ 80%)
- Dim reset time shown next to each

**Line 2 — Session info** *(always shown):*

```
 main+  ·  claude-sonnet-4-6 (high)  ·  12%
```

- Git branch with status indicators: `+` staged changes (yellow), `*` unstaged changes (orange)
- Active model name, with effort level in parentheses if set
- Context window usage %, color-coded green → yellow → red

## Requirements

- `bash` 4+
- `git` (for branch display)
- `sed`, `date` (GNU coreutils — standard on Linux; included via Git Bash or WSL on Windows)
- No `jq` required — JSON parsing is done with `sed`
