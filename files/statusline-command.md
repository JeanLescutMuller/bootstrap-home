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
🤖 Sonnet 5 (high)    🖥️  mac    📂 ~/dev/bootstrap-home    🌿 main (?2 !1)
🆔 e6d08010-604b-46dd-b912-7ae2380b382f    ⚙️  53098    5h reset at 16h03
💬 [███░░░░░] 44%    5h [░░░░░░░░] 3%    7d [░░░░░░░░] 10%    💾 15.0G/16.0G
```

| Line | Content | Color scheme |
|------|---------|---------------|
| 1 | 🤖 model + effort · 🖥️ short hostname · 📂 cwd · 🌿 git branch + status (only inside a repo) | Grayscale, brightness = importance — **except hostname and the git status counts**, which deliberately break the grayscale pattern (see below) |
| 2 | 🆔 session UUID (**leftmost**, deliberately — this is the field you need if the terminal crashes and you have to find the transcript/session again) · ⚙️ shell PID · rotating info (see below) | Grayscale, dimmer = less important |
| 3 | 💬 context-window usage · `5h` rate-limit usage (or `Blocked - resets in Xh Ym` past 100%) · `7d` rate-limit usage (same blocked behavior) · 💾 memory used/total | Criticality color (green <70%, yellow <70-90%, red ≥90%), applied to the whole segment (icon + bar fill + percentage), not just the bar |

Session title (`🏷️`) used to be on line 2 — dropped, since it's already shown in the terminal tab/prompt-box, redundant here.

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

### Background `git fetch`

So ahead/behind (`⇡`/`⇣` above) stays fresh without a manual fetch. Roughly every 30s: `(seconds % 30) < 10` is a 10s-wide window every 30s, timed to land within the ~10s refresh interval without needing any state persisted between invocations (each render is a fresh process - there's nothing to persist *to*). `10#$(date +%S)` - not just `$(date +%S)` - because `date +%S` zero-pads ("08", "09") and bash `$(( ))` reads a leading zero as octal, where 8/9 aren't valid octal digits; crashes without the explicit base-10 prefix.

Runs backgrounded and disowned - a slow or offline fetch must never block the statusline's own render - guarded by an `mkdir`-based lock (atomic, no `flock` dependency, one lock directory per repo path) so a slow fetch can't stack a second one on top of it before the first finishes. Verified directly, not just assumed correct: forced the 30s window open and slowed the fetch artificially, confirmed the lock directory exists while a fetch is in flight, confirmed a concurrent second invocation sees the held lock and skips cleanly with no error, confirmed cleanup after. Failures (offline, no remote) are silent on purpose - nothing useful to show on every render for those.

### Rotating info (line 2, end)

Was always the datetime; now rotates through three states, replacing the dropped session-title field's old position at the end of line 2. Same seconds-bucket trick as the fetch scheduler: `(seconds / 10) % 3` cycles through all three roughly every 30s, changing in step with the refresh rate rather than jumping unpredictably.

1. Datetime (`08/22 22:59:00`) - the original, unchanged behavior.
2. 7-day rate-limit reset (`7d reset on Saturday 29th at 15h`) - full weekday name + ordinal day + hour, no minutes (a reset that far out doesn't need minute precision).
3. 5-hour rate-limit reset (`5h reset at 16h03`) - hour + minute (this one's typically same-day, so no date needed), `h` as the separator instead of `:`.

Both still rotate through even while their window shows "Blocked" on line 3 (past 100%, counting down) - knowing the exact reset time is arguably *more* useful then, not less.

Two portability details worth knowing if this ever needs revisiting:
- **Epoch formatting**: `fmt_epoch()` branches on `uname -s` (same `Darwin` check already used for the memory segment) - macOS's `date -r <epoch>` vs. Linux's `date -d @<epoch>`, completely different flag meanings between the two (`-r` on Linux `date` means "read this file's mtime", not "use this epoch" - would silently do the wrong thing if not branched).
- **Locale**: found live that `%A` (weekday name) respects the machine's locale - this machine's `LC_TIME` is `fr_CH`, so an unguarded `date +%A` rendered "samedi" instead of "Saturday". `fmt_epoch()` forces `LC_TIME=C`, same precedent as the `LC_ALL=C` already forced in the memory-segment `awk` calls above (same class of bug: locale-dependent formatting silently producing the wrong output). No `date` format specifier does the ordinal suffix ("2nd") on either platform either - `ordinal_suffix()` computes it by hand from the day-of-month number.

Design history, if you want the reasoning behind a specific choice: originally 4 lines with the UUID alone on the last line; collapsed to 3 by merging UUID+title+PID onto one line and context+usage+memory onto another. Emoji and colors were chosen interactively (candidates presented with live-rendered previews) — swap freely, nothing here is load-bearing except the field names below.

### Live rate-limit reading

`rate_limits.*` in the stdin payload (see below) is a **per-session snapshot** that Claude Code only refreshes when *that specific session* sends a prompt — confirmed live, 2026-08-23: a session idle for ~7 hours held the exact same `resets_at`/`used_percentage` the whole time, unmoved by real completions happening in *other* sessions, then jumped in one step the instant a prompt was finally sent in it. Windows themselves appear to be created on-demand with a fixed `created_at + 5h` boundary, not a continuously-rolling "+5h from now" — confirmed by watching one window's boundary hold rock-steady across ~7 hours of continuous real traffic in an active session, then jump exactly once (to a genuinely new boundary) the moment a new window had to be created. Between a window's expiry and the next real request, there's no window at all — nothing to refresh, so the client just keeps showing the last thing it knew, however old.

So an idle session's bar can be hours stale with no way to tell just by looking at it.

Fixed by calling the same endpoint the `/usage` command itself calls internally (`fetchUtilization`, found via `strings` on the Claude Code executable): `GET https://api.anthropic.com/api/oauth/usage`, bearer-token-authenticated from the OS-native credential store (macOS Keychain service `Claude Code-credentials`; Linux would read `~/.claude/.credentials.json` instead — not yet implemented here, see Known quirks). `statusline-usage-fetch.sh` does this, self-throttled (~180s file-cache TTL, 30s cross-session `mkdir`-lock so several concurrently-rendering sessions don't all hit the endpoint at once) so calling it on every render is cheap. `statusline-command.sh` calls it, then overrides the stdin snapshot with its cache whenever a reading fresher than 10 minutes exists, falling back to the stdin snapshot otherwise (no token, offline, endpoint down).

Ported from [sirmalloc/ccstatusline](https://github.com/sirmalloc/ccstatusline)'s `src/utils/usage-fetch.ts`, which reverse-engineered this same endpoint first and handles considerably more than this port does (API schema migrations, enterprise no-rate-limit accounts, 429 backoff, token fingerprinting) — this is a minimal bash port covering just what this script needs.

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

`rate_limits.*` is the official rate-limit data straight from Anthropic, but it's a per-session cache that can go stale for hours (see "Live rate-limit reading" above) — `statusline-command.sh` overrides it with a live reading when one is available.

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
- `statusline-usage-fetch.sh` (live rate-limit reading) is macOS-only right now — it reads the OAuth token from Keychain and has no Linux fallback yet. On the VM this fails silently (empty token → script exits 0, no cache written) and `statusline-command.sh` just falls back to the stdin snapshot, same as before this feature existed. Porting the `~/.claude/.credentials.json` path from ccstatusline's `usage-fetch.ts` would close this gap.
