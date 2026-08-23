# General conventions (all dev machines)

- `~/dev/` — all source repos, flat (no category subfolders).
- `~/opt/<project>/` — deployed/installed runtime copy (what a launchd job / systemd unit / cron points at), separate from the git source in `~/dev/<project>`.
- `~/.local/bin/` — symlinks into `~/opt/<project>/`, never real files.
- `~/dev/<x>` folder name must match the real GitHub repo name (check `git remote -v`, don't assume) — a drifted `~/opt/` copy name doesn't override this.

# Machine-specific

- **Debian VM**: `~/opt/` (user's own tools) is distinct from root-owned `/opt/` (root-run systemd services, e.g. `/opt/auto-commit`).
- Naming can still drift per tool: `claude-session-manager` — source `~/dev/claude-session-manager`; deployed copy `~/opt/claude_session_manager` (underscore, legacy). Scheduled via macOS LaunchAgent (`com.csm.reindex-sync.plist`) or Debian systemd user unit (`com.csm.reindex-sync.{service,timer}`).
