# `AGENTS.md` and its `CLAUDE.md` symlink

## Every session loads it, so keep it small

Every session that works in a folder is given **every `AGENTS.md` on the path from the repo root down to that folder, parents first**, before it does anything. A word in `AGENTS.md` is paid for on every turn of every session, whether the task needs it or not. A word in `doc/` or `TODO.md` is paid for only when an agent decides to open that file.

```
editing src/pipeline/ingest/ loads, in order:
    ./AGENTS.md                       project-wide rules
    ./src/AGENTS.md                   all source code
    ./src/pipeline/ingest/AGENTS.md   this folder
```

| Budget | |
|---|---|
| one `AGENTS.md` | aim ≤ 400 words, never above ~600 |
| the whole chain loaded in the deepest folder | ≤ ~1,900 words |

**Over budget?** Find the longest passage that is *explaining* rather than *instructing* and move it to `doc/` or `TODO.md`. No rule needs to be dropped.

## What it holds

- **Rules, not evidence.** A rule is one or two imperative sentences plus a pointer (`→ doc/pnl.md §3`). The table, measurement or worked example proving it lives in `doc/` or `TODO.md`.
- **Never repeat a parent.** Put each rule once, at the level that owns it; a pointer to a parent's rule is fine, a copy drifts and then contradicts. The chain is path-based: if a folder's work routinely touches a sibling (a shared library), say so and link there.
- **Self-sufficient.** An agent reading only the `AGENTS.md` chain, and never a README, must have every rule it needs.
- **Contents, in order:** the purpose in one line, in the user's words · the rules and traps · what must not be touched · the commands to test and deploy · the core vocabulary table (~10 words; the full list is in `VOCABULARY.md`) · a "where to look" table pointing at `doc/`, `TODO.md` and the design files.
- Once code exists, rules derived from `DESIGN.md` go here as one-line rules pointing back at the design section that explains them.

Template: [`../templates/AGENTS.template.md`](../templates/AGENTS.template.md).

## `CLAUDE.md` is a symlink to it

Codex reads `AGENTS.md`, Claude reads `CLAUDE.md`; the symlink makes both read the same file, so the rules cannot diverge. Every `AGENTS.md` gets one, at every level.

```bash
ln -sfn AGENTS.md CLAUDE.md                # in the same folder, relative target
git ls-files -s CLAUDE.md                  # must show mode 120000 (a symlink), not 100644
```

If a real `CLAUDE.md` already exists, merge its content into `AGENTS.md` first, then replace it with the link.
