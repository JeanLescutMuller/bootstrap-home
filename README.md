# my-setup

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
- `tmux.conf` → `~/.tmux.conf` (reloaded live if a tmux server is running). Deliberately does **not** include notify's `AGENT-NOTIFY` hooks block — that's notify's own territory, injected by `notify init` (see `tools.sh` below), not baked into a static dotfile. Baking a prior machine's already-injected block into this file was an earlier bug here: it shipped notify's tmux hooks to a machine that never had notify installed, producing `command not found` errors on every pane switch.

**Agent links** (`modules/agent_links.sh`: a read-only copy under `~/opt/my-setup/`, linked from where the agents look, so an edit through a link fails; edit here, then `INSTALL=true bash bootstrap.sh agent_links`; `uninstall.sh` removes the links and copies):
- The machine-wide conventions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) moved to `my-context` on 2026-10-16 (`my-context/init/AGENTS_LOCAL.md`, linked by its `install.sh`); this module only removes the old copy `~/opt/my-setup/home_AGENTS.md` once nothing links to it.
- `skills/<name>/` → `~/opt/my-setup/skills/<name>/` ← `~/.claude/skills/<name>` and `~/.agents/skills/<name>` — a real folder already at a link path is replaced only if it is an identical old copy; a skill removed from `skills/` loses its copy and links. shared global skills for Claude Code and Codex, loaded on demand when their situation applies: `config-ownership` (settings.json key ownership + managed-block convention), `machine-name` (the rule and snippets for this machine's name), `data-moves` (hash-verified moves and approved delete batches across machines), `google-workspace` (Google Workspace via Google's `gws` CLI; the generated per-service skills merged into one), `outlook` (Outlook.com / Hotmail mail through the audited Softeria ms-365-mcp-server: the `outlook` MCP tools, or `scripts/ol.sh` from the shell), `linkedin` (LinkedIn through stickerdaniel/linkedin-mcp-server called from the shell, Chrome for what it cannot do), `linkedin-profile` (editing the user's own LinkedIn profile silently through Chrome: backup, review page, per-item save, Notify network off, restore), `whatsapp` (WhatsApp: reads through the `whatsapp-cli` plugin's local data, writes through Chrome on WhatsApp Web, never a window to the front). Skills that belong to a project live in its repo and are linked by its own `install.sh`: `inject-session` (`agent-session-manager`), `patch-statusline` (`agent-statusline`), `personal-context`, `writing-for-others`, `documentation-writing`, `python-coding`, `shell-scripting`, `jupyter-notebooks`, `code-minimization` (`my-context`: the skills about how the user works), `jobs-and-services` (`job-runner`).

**`~/.zshrc` / `~/.bashrc`**: never overwritten wholesale, and no separate files land on the target machine for this. `files/configure_shellrc.sh zsh|bash` generates the block content on the fly — organized by *topic* (PATH → `ls`/`ll` → history → prompt), not by shell, branching internally only where bash/zsh syntax genuinely differs (history flags, `PS1` escapes). Its output is written directly into `~/.zshrc` or `~/.bashrc` by `_deploy_managed_block` as a single box-delimited, hash-verified block — removed and reconstructed on every install, everything outside the block left completely alone. Deliberately does **not** wire up nvm or conda: those are each tool's own job (`nvm install` / `conda init` already append their own shell integration the moment they're installed) — `my-setup` carrying dormant, tool-specific logic for tools it doesn't install is scope creep. If a machine already has nvm/conda wired into its `.zshrc`/`.bashrc` from before, that wiring is preserved outside the managed block during migration, not deleted. The block:
- Opens with a visible `DO NOT EDIT` warning — put your own customizations below the block, not inside it.
- Carries a `sha256:` of its own content in the closing marker. If the block was hand-edited since the last deploy, the hash won't match on the next run: `bootstrap.sh` prints a diff of what changed and **aborts that file** rather than clobbering the edit — nothing else deployed by this project is affected.
- Uses the exact same box format as `notify`'s tmux-hook injection (`deploy_managed_block` in `notify`'s own script) — kept in sync deliberately, so every project that injects a block into a file it doesn't fully own looks and behaves identically.

**Modules** (`modules/`, real logic only):
- `dev_layout.sh` — ensures `~/dev`, `~/opt`, `~/.local/bin` exist; on the Mac, links `~/gdrive` → My Drive as mounted by the Google Drive app (`brew install --cask google-drive`, stream mode, installed by hand: it needs sudo)
- `agent_links.sh` — the agent links above, and the migrations from earlier layouts (`~/AGENTS.md`, `~/dev/AGENTS.md`, renamed skills)
- `gitconfig.sh` — user identity, `pull.rebase=false`, and the right credential helper for this OS (`osxkeychain` on macOS, `store` on Linux)
- `claude_config.sh` — merges `respondToBashCommands`/`theme`/`statusLine`/`cleanupPeriodDays`/`autoMemoryEnabled`/`skillOverrides`/`pluginConfigs` (Claude reads every `AGENTS.md`, projects need no `CLAUDE.md`; Anthropic's `google-workspace` hidden here, `gws` covers it; the `whatsapp-cli` plugin's own skill hidden, skill `whatsapp` replaces it; memory off: facts go in AGENTS.md or a skill) into `~/.claude/settings.json`, and removes the retired `claudeMdExcludes` via `python3` (already a required dependency of `agent-session-manager`'s own installer), touching only those keys. Deliberately does **not** manage `hooks` (`agent-session-manager`'s own job) or `enabledPlugins`/`extraKnownMarketplaces` (`notify`'s own job) — each tool that owns a piece of this file manages it itself.
- `tools.sh` — uses `~/dev/<name>` if present, else a scratch clone deleted afterwards (every `install.sh` deploys into `~/opt/<name>/`), and deploys `agent-session-manager`, `agent-notify`, [`agent-statusline`](https://github.com/JeanLescutMuller/agent-statusline) (the shared Claude/Codex statusline renderer, its lazy cache, and the Codex status-line-command binary patch) and [`agent-usage-tracker`](https://github.com/JeanLescutMuller/agent-usage-tracker) (quota/token/spend history, pollers and telemetry receiver, which the statusline feeds) — independent projects, not my-setup's own. For `notify` specifically, also runs `notify init` after `install.sh` — that's what actually injects the tmux hooks (idempotent, guarded by notify's own marker), and is the only thing that's allowed to.
- `remote_control.sh` — macOS only: the LaunchAgent `com.jeanlescut.my-setup` (KeepAlive) runs `~/opt/my-setup/remote_control.sh` (from `files/`), which keeps `claude remote-control --permission-mode auto` running in `~/dev`, so a Claude session on this Mac can be started from the phone (Claude app or claude.ai/code) at any time, as long as the Mac is awake. Log: `~/opt/my-setup/logs/remote-control.log` (start, exit, errors; the redrawn screen goes to `/dev/null`). Restarted only when the script or plist changed, since a restart ends every session open from the phone. `uninstall.sh` removes it.

**Notes and tools run by hand** (never deployed):
- [`doc/shift_enter_over_ssh.md`](doc/shift_enter_over_ssh.md) — why Shift+Enter submits in Claude Code over plain SSH (use Ctrl+J there), works in tmux, and why nothing is patched; [`tools/terminal_key_probe.py`](tools/terminal_key_probe.py) measures the key bytes again after an update
- [`tools/context_inventory.py`](tools/context_inventory.py) — what each Claude / Codex session loads at startup vs on use, in tokens

## Explicitly not here

No Meta-specific configuration (corporate proxy, `fbsource` paths, internal Claude plugins) and no root-level services — see `bootstrap-vm` for anything that needs to own the whole machine.
