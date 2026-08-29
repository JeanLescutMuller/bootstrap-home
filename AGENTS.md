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

## Codex patch builds

Codex patch/build/deploy work must be encoded as one deterministic, idempotent,
quiet shell script before running it. The script must capture verbose compiler
output in a log and print only milestones plus the final result. Never drive a
build through repeated tool polling or stream compiler output through the model:
this wastes context and quota. A single long-running scripted invocation is the
normal path; use the model only to diagnose its final failure summary.

Treat this as a hard quota-safety rule, not a preference. Do not spend LLM tokens
manually orchestrating any reproducible install or build; improve and run the
single installer instead. Codex status-line patching is owned by
`scripts/install-codex-statusline-patch.sh` and the `codex_patch` module.

## Statusline cache design

Shared Claude/Codex quota caches use a 60-second TTL. Keep provider-specific
refresh work lazy: a renderer refreshes stale data only after acquiring the
shared lock, otherwise it displays the stale value and continues.
