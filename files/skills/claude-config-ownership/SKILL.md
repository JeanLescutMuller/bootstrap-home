---
name: claude-config-ownership
description: This machine's ownership map for ~/.claude/settings.json keys, and the managed-config-block convention used across its dotfiles. Use before hand-editing ~/.claude/settings.json, or before hand-editing a block inside ~/.zshrc, ~/.bashrc, or ~/.tmux.conf.
---

## `~/.claude/settings.json` key ownership

No single tool owns this whole file — each owner manages specific keys and leaves the rest alone:

- `respondToBashCommands`, `theme`, `statusLine` — owned by `bootstrap-home` (`modules/claude_config.sh`)
- `hooks` — owned by `claude-session-manager`'s own `install.sh`
- `enabledPlugins`, `extraKnownMarketplaces` — owned by `notify`'s own `install.sh`

Don't hand-edit a key outside the tool that owns it. Fix it in that tool's install/config script instead, so the fix survives the next bootstrap run instead of being silently overwritten.

## Managed config block convention

`~/.zshrc`, `~/.bashrc` (via `bootstrap-home`), and `~/.tmux.conf` (via `notify`'s tmux-hook injection) each contain a box-delimited section marked `DO NOT EDIT`, carrying a `sha256:` hash of its own content in the closing marker. If that block is hand-edited, the owning tool's next managed write detects the hash mismatch, prints a diff, and aborts touching that file rather than clobbering the edit.

If a block needs to change, edit the source that generates it (`bootstrap-home`'s `files/configure_shellrc.sh` for shell rc, `notify`'s own script for the tmux block) and let the tool redeploy it — don't hand-edit inside the block markers.
