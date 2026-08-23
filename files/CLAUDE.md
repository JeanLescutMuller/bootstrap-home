# General conventions (all dev machines)

- `~/dev/` — all source repos, flat (no category subfolders).
- `~/opt/<project>/` — deployed/installed runtime copy (what a launchd job / systemd unit / cron points at), separate from the git source in `~/dev/<project>`.
- `~/.local/bin/` — symlinks into `~/opt/<project>/`, never real files.
- `~/dev/<x>` folder name must match the real GitHub repo name (check `git remote -v`, don't assume) — a drifted `~/opt/` copy name doesn't override this.
- Never leave the shell's working directory changed after a spontaneous `cd` — change back before finishing, or ask first. The statusline's git-status segment reads the shell's live cwd, so a stray `cd` breaks it for the rest of the session, not just that command.

# Machine-specific

- **macOS → Debian VM**: reachable via `ssh H-Frank-1` (alias in `~/.ssh/config`; Hostinger EC2, Debian 12). Setup/provisioning details live in `bootstrap-vm`, not here.
- **Debian VM**: `~/opt/` (user's own tools) is distinct from root-owned `/opt/` (root-run systemd services, e.g. `/opt/auto-commit`).
- Naming can still drift per tool: `claude-session-manager` — source `~/dev/claude-session-manager`; deployed copy `~/opt/claude_session_manager` (underscore, legacy). Scheduled via macOS LaunchAgent (`com.csm.reindex-sync.plist`) or Debian systemd user unit (`com.csm.reindex-sync.{service,timer}`).
