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

**`~/.zshrc` / `~/.bashrc`**: never overwritten wholesale, and no separate files land on the target machine for this. `shellrc_common` (shared: PATH, `ls`/`ll` aliases, `HISTSIZE`, nvm) and whichever of `zshrc_thin`/`bashrc_thin` matches `$SHELL` (prompt + history behavior, which genuinely differ between the two shells) are concatenated at deploy time into a single box-delimited, hash-verified block written directly into `~/.zshrc` or `~/.bashrc` by `_deploy_managed_block` — removed and reconstructed on every install, everything outside the block left completely alone. The `files/` split exists only in this repo, to keep the shared logic in one place to maintain, without adding `source`-file indirection on the target machine. The block:
- Opens with a visible `DO NOT EDIT` warning — put your own customizations below the block, not inside it.
- Carries a `sha256:` of its own content in the closing marker. If the block was hand-edited since the last deploy, the hash won't match on the next run: `bootstrap.sh` prints a diff of what changed and **aborts that file** rather than clobbering the edit — nothing else deployed by this project is affected.
- Uses the exact same box format as `notify`'s tmux-hook injection (`deploy_managed_block` in `notify`'s own script) — kept in sync deliberately, so every project that injects a block into a file it doesn't fully own looks and behaves identically.

**Modules** (`modules/`, real logic only):
- `dev_layout.sh` — ensures `~/dev`, `~/opt`, `~/.local/bin` exist
- `gitconfig.sh` — user identity, `pull.rebase=false`, and the right credential helper for this OS (`osxkeychain` on macOS, `store` on Linux)
- `tools.sh` — clones/updates and deploys `claude-session-manager`, `notify`, `statusline`. For `notify` specifically, also runs `notify init` after `install.sh` — that's what actually injects the tmux hooks (idempotent, guarded by notify's own marker), and is the only thing that's allowed to.

## Explicitly not here

No Meta-specific configuration (corporate proxy, `fbsource` paths, internal Claude plugins) and no root-level services — see `bootstrap-vm` for anything that needs to own the whole machine.
