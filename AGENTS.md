# bootstrap-home development instructions

These instructions govern development of this repository.

## Instruction-file scope

When the user mentions `AGENTS.md` or `CLAUDE.md`, determine which scope they
mean before editing anything:

- Repository-development feedback belongs in this repository-root
  `AGENTS.md`. `CLAUDE.md` at the repository root is a compatibility symlink to
  this file.
- General machine-wide instructions that bootstrap-home should deploy to new
  machines belong in `files/home_AGENTS.md`, which is installed as
  `~/AGENTS.md`.

Do not assume an unqualified `AGENTS.md` or `CLAUDE.md` request targets the
deployment payload merely because `files/home_AGENTS.md` exists. Infer the
scope from the request, and ask when it remains ambiguous.

## Deferred work

See `TODO.md` for deliberately postponed project improvements.

## Statusline cache design

Shared Claude/Codex quota caches use a 60-second TTL. Keep provider-specific
refresh work lazy: a renderer refreshes stale data only after acquiring the
shared lock, otherwise it displays the stale value and continues.
