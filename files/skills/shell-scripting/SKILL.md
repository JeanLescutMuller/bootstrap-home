---
name: shell-scripting
description: Personal bash/shell scripting conventions. Use when writing or editing a .sh script, especially an install/bootstrap-style script, for this user.
---

## `install.sh` scripts

Every personal tool's `install.sh` must be:
- **Idempotent** — safe to blind re-run any time, including on a fresh machine.
- **Self-migrating** — if it detects a stale prior layout (old paths, old naming), move it to the current layout automatically rather than requiring manual cleanup.

## Bash habits

- Prefer `printf -v` over `eval` for dynamic variable assignment.
- `jq`'s `//` operator treats `false` (and `null`, `0`, `""`) as falsy — when checking whether a key is merely *present*, use `has("key")` instead of `.key // default`.
