# statusline-command.sh — design notes

Reference documentation for `files/statusline-command.sh`, deployed as a plain
dotfile to `~/.claude/statusline-command.sh`. The `statusLine` wiring in
`~/.claude/settings.json` is `claude_config.sh`'s job (see `modules/`), not
this script's — this file is content-only, kept for the non-obvious design
knowledge, not deployed itself.

Not to be confused with `notify` (a separate project): notify handles tmux
pane bg / terminal-tab title / sound-bell/TTS on session-state changes across
multiple panes. The status line is Claude Code's own built-in `statusLine`
setting; this script is just what's plugged into it.

## Layout

Three lines:

```
🤖 Sonnet 5 (high)    📂 /Users/jeanlescut/secondbrain/03_tools/notify    🌿 main (+7 -4)
🆔 e6d08010-604b-46dd-b912-7ae2380b382f    🏷️  Claude status bar    ⚙️  53098
💬 [███░░░░░] 44%    5h [░░░░░░░░] 3%    7d [░░░░░░░░] 10%    💾 15.0G/16.0G
```

| Line | Content | Color scheme |
|------|---------|---------------|
| 1 | 🤖 model + effort · 📂 cwd · 🌿 git branch+diffstat (only inside a repo) | Grayscale, brightness = importance (model brightest, git dimmest) |
| 2 | 🆔 session UUID (**leftmost**, deliberately — this is the field you need if the terminal crashes and you have to find the transcript/session again) · 🏷️ session title (only if renamed via `/rename`) · ⚙️ shell PID | Grayscale, dimmer = less important (UUID/PID are rarely-read technical fields) |
| 3 | 💬 context-window usage · `5h` rate-limit usage (or `Blocked - resets in Xh Ym` past 100%) · `7d` rate-limit usage (same blocked behavior) · 💾 memory used/total | Criticality color (green <70%, yellow <70-90%, red ≥90%), applied to the whole segment (icon + bar fill + percentage), not just the bar |

Design history, if you want the reasoning behind a specific choice: originally 4 lines with the UUID alone on the last line; collapsed to 3 by merging UUID+title+PID onto one line and context+usage+memory onto another. Emoji and colors were chosen interactively (candidates presented with live-rendered previews) — swap freely, nothing here is load-bearing except the field names below.

## The statusLine JSON payload

Claude Code pipes a JSON object to the command on stdin. The fields this script uses (confirmed by capturing a live payload on 2026-08-18 — **not** exhaustively documented anywhere public, so if a field goes missing after a Claude Code update, re-capture and check):

```jsonc
{
  "session_id": "...",           // stable per-session UUID
  "session_name": "...",         // set via /rename; absent/null if never renamed
  "cwd": "...",
  "effort": { "level": "high" }, // reasoning effort
  "model": { "display_name": "Sonnet 5" },
  "context_window": {
    "used_percentage": 44,
    "context_window_size": 1000000  // can exceed 200k in long-context mode
  },
  "rate_limits": {
    "five_hour": { "used_percentage": 3, "resets_at": 1787083200 },  // unix epoch
    "seven_day": { "used_percentage": 10, "resets_at": 1787598000 }
  }
}
```

`rate_limits.*` is the official rate-limit data straight from Anthropic — no need for a third-party tool (e.g. `ccusage`) to get 5-hour/7-day usage-block info.

### Re-capturing the payload (if the schema ever changes)

Point `statusLine.command` at a wrapper that tees stdin to a file, wait ~10s for a natural refresh, then restore:
```bash
cat > /tmp/sl-debug.sh <<'EOF'
#!/bin/bash
input=$(cat)
echo "$input" > /tmp/statusline-debug.json
echo "$input" | bash ~/.claude/statusline-command.sh
EOF
# temporarily edit settings.json's statusLine.command to `bash /tmp/sl-debug.sh`,
# wait for a refresh, inspect /tmp/statusline-debug.json, then restore the command.
```

## Testing changes offline

Feed a captured (or hand-built) JSON payload straight to the script — no need to wait for a live Claude Code render:
```bash
cat /tmp/statusline-debug.json | bash files/statusline-command.sh
```
Useful for checking severity thresholds (context/rate-limit/memory at low/mid/high %, and the ≥100% "Blocked" countdown) by editing the `used_percentage`/`resets_at` fields in a copy of the payload before piping it in.

## Known quirks

- `jq` must be reachable in the invoking shell's inherited `PATH` (the script relies on Claude Code passing through the environment it was launched with — it does not source `.zshrc`/`.bashrc`, so don't assume anything beyond what's in your login shell's exported `PATH`).
- Number formatting forces `LC_ALL=C` in every `awk` call — without it, a non-English locale (e.g. `fr_FR`) turns `1.0M` into `1,0M`.
- **macOS-only**: the 💾 memory segment comes from `top -l 1 -s 0 -n 0`'s `PhysMem:` line and `sysctl -n hw.memsize`. Not rewritten for Linux yet (`free`/`/proc/meminfo`) — will misbehave when this dotfile deploys to the VM. Known limitation, not yet fixed.
