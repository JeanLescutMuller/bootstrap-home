---
name: shell-scripting
description: Personal bash/shell scripting conventions. Use when writing or editing a .sh script, especially an install/bootstrap-style script, for this user.
---

## `install.sh` scripts

Every personal tool's `install.sh` must be:
- **Idempotent** — safe to blind re-run any time, including on a fresh machine.
- **Self-migrating** — if it detects a stale prior layout (old paths, old naming), move it to the current layout automatically rather than requiring manual cleanup.
- **Skills linked, never copied** — each folder `skills/<name>/` of the repo becomes a symlink `~/.claude/skills/<name>` and `~/.agents/skills/<name>` pointing into the clone (`~/dev/<repo>` on every machine); `uninstall.sh` removes only the links that point into this clone. A real folder already at the link path is replaced only if identical (ignoring `*.bak`); otherwise it is kept, with a warning.

## Bash habits

- Prefer `printf -v` over `eval` for dynamic variable assignment.
- `jq`'s `//` operator treats `false` (and `null`, `0`, `""`) as falsy — when checking whether a key is merely *present*, use `has("key")` instead of `.key // default`.
