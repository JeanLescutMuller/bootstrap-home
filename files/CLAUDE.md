# Machine layout conventions

These apply on both the macOS laptop and the Debian VM.

- `~/dev/` — all source code / project repos, flat (no category subfolders). This is the IDE-agnostic replacement for the old `~/secondbrain/` (Meta-era naming) and `~/jupyter_workspace/` (Jupyter-era naming), both retired 2026-08-19.
- `~/opt/<project>/` — deployed/installed runtime copies: the actual files a launchd job / systemd service / cron job points at (scripts, logs, state), as opposed to the git source in `~/dev/<project>`. Mirrors the Unix `/opt` convention for optional installed software; recognizable and consistent across macOS and Debian.
  - On the Debian VM, this is distinct from the system-level `/opt/` (root-owned, e.g. `/opt/auto-commit`, used by root-run systemd services). `~/opt/` is for the user's own deployed tools; `/opt/` (no `~`) is for things that must run as root.
- `~/.local/bin/` — deployed binaries and wrapper scripts (XDG standard, already on `PATH`). Keep as-is.

When deploying a new tool/service, put its git source under `~/dev/`, and if it needs an installed runtime copy separate from the source (e.g. because a service/launchd job/cron job runs from a fixed path), install it under `~/opt/<project>/`, not directly under `~/` and not under `~/services/`.

## Naming: match the actual repo name

Name the folder under `~/dev/` after the real GitHub repo name (dashes vs underscores as the repo actually uses it) — check `git remote -v` if unsure, don't assume. Don't let a deployed copy's naming (`~/opt/<project>/`) dictate the source folder's name if it drifted from the repo name.

Example: `claude-session-manager` — the GitHub repo is `JeanLescutMuller/claude-session-manager` (dash). Source lives at `~/dev/claude-session-manager` (git repo) on both machines. Deployed/running copy is `~/opt/claude_session_manager` (underscore — an old naming choice baked into the install scripts; not worth a churn-y rename since nothing else depends on the source folder's name matching it), referenced by:
- macOS: `~/Library/LaunchAgents/com.csm.reindex-sync.plist` and the lifecycle hooks in `~/.claude/settings.json`
- Debian VM: `~/.config/systemd/user/com.csm.reindex-sync.{service,timer}` and the lifecycle hooks in `~/.claude/settings.json`
