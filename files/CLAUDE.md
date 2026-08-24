# General conventions (MacBook + Debian VM)

- `~/dev/` — all source repos, flat (no category subfolders).
- `~/opt/<project>/` — deployed/installed runtime copy (what a launchd job / systemd unit / cron points at), separate from the git source in `~/dev/<project>`. Everything a project owns lives here as a real file — code, logs, state, and the scheduler/trigger definition itself (LaunchAgent `.plist`, systemd `.service`/`.timer`). The OS-mandated location (`~/Library/LaunchAgents/`, `~/.config/systemd/user/`) holds only a symlink pointing back into `~/opt/<project>/` — never a real file there.
- `~/.local/bin/` — symlinks into `~/opt/<project>/`, never real files. Same symlink-only rule as the scheduler files above.
- `~/dev/<x>` folder name must match the real GitHub repo name (check `git remote -v`, don't assume) — a drifted `~/opt/` copy name doesn't override this.
- Never leave the shell's working directory changed after a spontaneous `cd` — change back before finishing, or ask first. The statusline's git-status segment reads the shell's live cwd, so a stray `cd` breaks it for the rest of the session, not just that command.

# Development vs deployment

Development (writing/editing code) happens on the MacBook only. The Debian VM, and any cloud targets, are deployment/runtime destinations — never write or edit code there directly. Which machine(s) a given project actually deploys to varies per-project (MacBook only, VM only, both, sometimes cloud too) — don't assume, check that project's own docs.

# Machine-specific

- **macOS → Debian VM**: reachable via `ssh H-Frank-1` (alias in `~/.ssh/config`; Hostinger EC2, Debian 12). Setup/provisioning details live in `bootstrap-vm`, not here.
- **Debian VM**: `~/opt/` (user's own tools) is distinct from root-owned `/opt/` (root-run systemd services, e.g. `/opt/auto-commit` as of 2026-08-24 — being migrated to user-scope `~/opt/` + `systemd --user`, since root/system scope should be the exception, not the default).
