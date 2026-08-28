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

**Dotfiles** (`files/`, deployed by the loop at the top of `bootstrap.sh` — copy-if-different, one replaceable `.bak` backup of anything it overwrites):
- `vimrc` → `~/.vimrc`
- `tmux.conf` → `~/.tmux.conf` (reloaded live if a tmux server is running). Deliberately does **not** include notify's `CLAUDE-NOTIFY` hooks block — that's notify's own territory, injected by `notify init` (see `tools.sh` below), not baked into a static dotfile. Baking a prior machine's already-injected block into this file was an earlier bug here: it shipped notify's tmux hooks to a machine that never had notify installed, producing `command not found` errors on every pane switch.
- `home_AGENTS.md` → `~/AGENTS.md` — canonical machine-wide conventions shared by coding agents. Its explicit name distinguishes this deployment payload from the repository-root `AGENTS.md`, which governs development of this project. `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` are symlinks to the deployed home file. The former dev-wide instructions have been merged into it, so provisioning removes the legacy `~/dev/AGENTS.md` and matching `~/dev/CLAUDE.md` symlink only when they still match the versions previously deployed by this project; customized files at either path are preserved.
- `statusline-command.sh` and `codex-statusline-command.sh` are thin provider adapters. Shared cache/formatting/refresh libraries deploy under `~/opt/bootstrap-home/statusline/lib`; neutral lazy caches live under the matching `state/` directory. Stale data is refreshed only by the renderer that wins an atomic lock, with bounded refresh time and stale-value fallback. Design details live in `files/statusline-command.md`.
- `skills/*/SKILL.md` → both `~/.claude/skills/*/SKILL.md` and `~/.agents/skills/*/SKILL.md` — shared global skills for Claude Code and Codex, loaded on demand when their situation applies: `claude-config-ownership` (settings.json key ownership + managed-block convention), `shell-scripting` (personal bash conventions), and `python-coding`.

**`~/.zshrc` / `~/.bashrc`**: never overwritten wholesale, and no separate files land on the target machine for this. `files/configure_shellrc.sh zsh|bash` generates the block content on the fly — organized by *topic* (PATH → `ls`/`ll` → history → prompt), not by shell, branching internally only where bash/zsh syntax genuinely differs (history flags, `PS1` escapes). Its output is written directly into `~/.zshrc` or `~/.bashrc` by `_deploy_managed_block` as a single box-delimited, hash-verified block — removed and reconstructed on every install, everything outside the block left completely alone. Deliberately does **not** wire up nvm or conda: those are each tool's own job (`nvm install` / `conda init` already append their own shell integration the moment they're installed) — `bootstrap-home` carrying dormant, tool-specific logic for tools it doesn't install is scope creep. If a machine already has nvm/conda wired into its `.zshrc`/`.bashrc` from before, that wiring is preserved outside the managed block during migration, not deleted. The block:
- Opens with a visible `DO NOT EDIT` warning — put your own customizations below the block, not inside it.
- Carries a `sha256:` of its own content in the closing marker. If the block was hand-edited since the last deploy, the hash won't match on the next run: `bootstrap.sh` prints a diff of what changed and **aborts that file** rather than clobbering the edit — nothing else deployed by this project is affected.
- Uses the exact same box format as `notify`'s tmux-hook injection (`deploy_managed_block` in `notify`'s own script) — kept in sync deliberately, so every project that injects a block into a file it doesn't fully own looks and behaves identically.

**Modules** (`modules/`, real logic only):
- `dev_layout.sh` — ensures `~/dev`, `~/opt`, `~/.local/bin` exist
- `statusline_cache.sh` — initializes static hostname caches, migrates the former `~/.claude/statusline-caches` data into the neutral runtime, and retires the old scheduled glances poller. Dynamic memory, quota, and per-cwd Git data are refreshed lazily by the renderers.
- `gitconfig.sh` — user identity, `pull.rebase=false`, and the right credential helper for this OS (`osxkeychain` on macOS, `store` on Linux)
- `claude_config.sh` — merges `respondToBashCommands`/`theme`/`statusLine` into `~/.claude/settings.json` via `python3` (already a required dependency of `claude-session-manager`'s own installer), touching only those keys. Deliberately does **not** manage `hooks` (`claude-session-manager`'s own job) or `enabledPlugins`/`extraKnownMarketplaces` (`notify`'s own job) — each tool that owns a piece of this file manages it itself.
- `codex_config.sh` — manages the Codex status-line selection and command table in `~/.codex/config.toml`, preserving every other Codex setting. `patches/codex-0.150.1-status-line-command.patch` adds a command-backed `custom` item; the provider adapter rotates the three Claude-style lines through Codex's single-line area every four seconds.
- `tools.sh` — clones/updates and deploys `claude-session-manager` and `notify`. For `notify` specifically, also runs `notify init` after `install.sh` — that's what actually injects the tmux hooks (idempotent, guarded by notify's own marker), and is the only thing that's allowed to.

## Explicitly not here

No Meta-specific configuration (corporate proxy, `fbsource` paths, internal Claude plugins) and no root-level services — see `bootstrap-vm` for anything that needs to own the whole machine.
