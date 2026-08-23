# Dev-wide conventions

Applies to any project under `~/dev/`, on both the macOS laptop and the Debian VM. See the global `~/.claude/CLAUDE.md` for machine-layout conventions (`~/dev` vs `~/opt` vs `~/.local/bin`) that apply even outside `~/dev`.

## Scheduling recurring jobs

Standard pattern for any recurring background job: a LaunchAgent (macOS, `~/Library/LaunchAgents/com.<x>.plist`) or a systemd `--user` service+timer (Linux, `~/.config/systemd/user/com.<x>.{service,timer}`), with `loginctl enable-linger` (best-effort) on Linux so the user unit runs without an active login session.
