# bootstrap-home

Personal, user-space environment bootstrapper. Gets dotfiles, the `~/dev`/`~/opt`
layout, git config, and a few personal tools onto any machine — safe to run
even on a machine you don't own (no root/sudo assumed anywhere).

This is deliberately the *small* half of a two-project split:
- **This repo** — personal dev environment, user-space only, works on any machine.
- [`bootstrap-vm`](https://github.com/JeanLescutMuller/bootstrap-vm) — provisioning a bare rented VM you own (root, SSH/user setup, optional cloud DS stack).

## Usage

```bash
bash bootstrap.sh              # check only, changes nothing
INSTALL=true bash bootstrap.sh # check + install dotfiles and all modules
INSTALL=true bash bootstrap.sh gitconfig   # dotfiles (always checked) + one module
```

## What it does

**Dotfiles** (`files/`, deployed by the loop at the top of `bootstrap.sh` — copy-if-different, timestamped backup of anything it overwrites):
- `vimrc` → `~/.vimrc`
- `tmux.conf` → `~/.tmux.conf` (reloaded live if a tmux server is running). Deliberately does **not** include notify's `### claude-notify BEGIN/END ###` hooks block — that's notify's own territory, injected by `notify init` (see `tools.sh` below), not baked into a static dotfile. Baking a prior machine's already-injected block into this file was an earlier bug here: it shipped notify's tmux hooks to a machine that never had notify installed, producing `command not found` errors on every pane switch.
- `CLAUDE.md` → `~/.claude/CLAUDE.md`
- `shellrc_common` → `~/.shellrc_common` — sourced by both bash and zsh (PATH, `ls`/`ll` aliases, `HISTSIZE`, nvm)
- `zshrc_thin` or `bashrc_thin` (whichever matches `$SHELL`) → `~/.zshrc_bootstrap` / `~/.bashrc_bootstrap` — prompt and history-behavior settings that genuinely differ between the two shells
- `~/.zshrc` / `~/.bashrc` are never overwritten — a `source` line is appended once if missing, so any existing content on the machine is left alone

**Modules** (`modules/`, real logic only):
- `dev_layout.sh` — ensures `~/dev`, `~/opt`, `~/.local/bin` exist
- `gitconfig.sh` — user identity, `pull.rebase=false`, and the right credential helper for this OS (`osxkeychain` on macOS, `store` on Linux)
- `tools.sh` — clones/updates and deploys `claude-session-manager`, `notify`, `statusline`. For `notify` specifically, also runs `notify init` after `install.sh` — that's what actually injects the tmux hooks (idempotent, guarded by notify's own marker), and is the only thing that's allowed to.

## Explicitly not here

No Meta-specific configuration (corporate proxy, `fbsource` paths, internal Claude plugins) and no root-level services — see `bootstrap-vm` for anything that needs to own the whole machine.
