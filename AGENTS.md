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

## Statusline and Codex patch builds

The shared Claude/Codex statusline renderer, its lazy cache library, and the
Codex status-line-command binary patch all moved to the independent
[`agent-statusline`](https://github.com/JeanLescutMuller/agent-statusline)
project. `modules/tools.sh` clones and deploys it the same way it deploys
`claude-session-manager` and `notify`; bootstrap-home itself no longer owns
any of that logic or touches `~/.codex/config.toml`.

That project's own build-script convention still applies wherever it's
developed: Codex patch/build/deploy work is encoded as one deterministic,
idempotent, quiet shell script, with verbose compiler output captured in a log
and only milestones plus the final result printed — never driven through
repeated tool polling or streamed through the model.
