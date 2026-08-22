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
🤖 Sonnet 5 (high)    🖥️  mac    📂 ~/dev/bootstrap-home    🌿 main (+7 -4)    08/22 22:59:00
🆔 e6d08010-604b-46dd-b912-7ae2380b382f    🏷️  Claude status bar    ⚙️  53098
💬 [███░░░░░] 44%    5h [░░░░░░░░] 3%    7d [░░░░░░░░] 10%    💾 15.0G/16.0G
```

| Line | Content | Color scheme |
|------|---------|---------------|
| 1 | 🤖 model + effort · 🖥️ short hostname · 📂 cwd · 🌿 git branch + status (only inside a repo) · datetime | Grayscale, brightness = importance (model brightest, datetime dimmest) — **except hostname and the git status counts**, which deliberately break the grayscale pattern (see below) |
| 2 | 🆔 session UUID (**leftmost**, deliberately — this is the field you need if the terminal crashes and you have to find the transcript/session again) · 🏷️ session title (only if renamed via `/rename`) · ⚙️ shell PID | Grayscale, dimmer = less important (UUID/PID are rarely-read technical fields) |
| 3 | 💬 context-window usage · `5h` rate-limit usage (or `Blocked - resets in Xh Ym` past 100%) · `7d` rate-limit usage (same blocked behavior) · 💾 memory used/total | Criticality color (green <70%, yellow <70-90%, red ≥90%), applied to the whole segment (icon + bar fill + percentage), not just the bar |

### Hostname color

The `🖥️ hostname` segment is the one field on line 1 that isn't grayscale — it gets its own color from a 14-shade blue/purple/cyan palette (`HOST_PALETTE` in the script), picked by hashing the short hostname (`hostname -s`) with SHA-256 and reducing mod the palette size. Deliberately **not** a hardcoded hostname→color lookup table: a lookup table leaves every new machine on an undefined color until someone edits the script and redeploys it everywhere, whereas hashing gives any hostname a stable color the moment `bootstrap-home` first deploys there, no maintenance.

Two things worth knowing if this ever needs revisiting:
- **SHA-256, not `cksum`.** `cksum` is a CRC — fine for error-detection, bad for bucketing: reducing it mod a small number clusters. Verified directly: `"mac"` and `"H-Frank-1"` landed on the exact same bucket under `cksum % 6`.
- **Palette size matters more than the hash.** The first version used only 6 colors, and even with a good hash (SHA-256), `mac`/`H-Frank-1` still collided — 6 buckets means collisions among just a few machines are expected by birthday-paradox math, not a sign of a bad hash. 14 shades resolves it for these two real machines with some headroom.
- The palette is deliberately confined to blue/purple/cyan, kept out of the green/yellow/red severity language used on line 3, so it never reads as a status/health signal.

### Git status: six cases, one color each

The `🌿 branch (...)` segment shows six independent git states, each with its own count and (mostly) its own color — deliberately replacing an earlier design that only showed tracked-file insertion/deletion *line* counts from `git diff --shortstat` (couldn't represent untracked files at all, and mixed line-granularity with file-granularity once untracked counts were added). All six are now file counts, shown only when non-zero:

| Case | Symbol | Color |
|---|---|---|
| Untracked files/folders | `?N` | cyan |
| Unstaged tracked changes | `!N` | same gray as the branch name — the most routine state, shouldn't compete for attention |
| Staged, not committed | `✚N` | blue |
| Ahead (unpushed local commits) | `⇡N` | purple |
| Behind (unmerged remote commits) | `⇣N` | same purple as ahead — same axis (local history vs. remote), the arrow glyph alone distinguishes direction |
| Merge conflicts | `✖N` | reuses `$SEV_RED` from line 3 — the one deliberate exception to "no severity colors outside line 3": a conflict is genuinely blocking/needs-action, closer to "critical" than to a routine file count, so reusing red reinforces its one existing meaning instead of diluting it |

Layout: untracked/unstaged/staged share one parenthetical in that order (git's own workflow order: untracked → edited → staged); ahead/behind sit outside the parens (different axis — your history vs. the remote's, not file edits); conflicts get their own trailing red group, appended last.

Implementation note, if this ever needs revisiting: computed via `git status --porcelain=v2`, not separate `git diff`/`git diff --cached` calls. A first attempt used `--diff-filter=U` to isolate conflicts and `--diff-filter=ACDMR`/`ACMR` (excluding `U`) on the unstaged/staged counts to avoid double-counting a conflicted path — but during an active conflict, git still reports the conflicted path as plain "Modified" against the index, so it showed up counted as *both* unstaged and conflicted (confirmed live with a real merge conflict). `porcelain=v2` avoids this structurally instead of by filtering: conflicted paths are their own line type (`u ...`), entirely separate from ordinary entries (`1 XY ...` / `2 XY ...`, where X = index/staged status and Y = worktree/unstaged status, `.` meaning no change in that dimension) — no overlap is possible by construction.

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
- The 💾 memory segment branches on `uname -s`: macOS uses `top -l 1 -s 0 -n 0`'s `PhysMem:` line and `sysctl -n hw.memsize`; Linux uses `/proc/meminfo` (`MemTotal - MemAvailable`, matching `free`'s definition of "used").
