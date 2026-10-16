# bootstrap-home development instructions

These instructions govern development of this repository.

## Instruction-file scope

When the user mentions `AGENTS.md` or `CLAUDE.md`, determine which scope they
mean before editing anything:

- Repository-development feedback belongs in this repository-root
  `AGENTS.md` (no `CLAUDE.md`: Claude reads `AGENTS.md` directly).
- General machine-wide instructions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`)
  live in `~/dev/my-context/init/AGENTS_LOCAL.md` since 2026-10-16, not here.

Infer from the request whether an unqualified `AGENTS.md` or `CLAUDE.md`
request means this repository's `AGENTS.md` or the machine-wide rules in
`my-context`, and ask when it remains ambiguous.

## Deferred work

Postponed improvements are Todoist tasks with `Repo: bootstrap-home` (skill `task-management`); [`viewer.html`](viewer.html) shows them.

## Statusline and Codex patch builds

The shared Claude/Codex statusline renderer, its lazy cache library, and the
Codex status-line-command binary patch all moved to the independent
[`agent-statusline`](https://github.com/JeanLescutMuller/agent-statusline)
project. `modules/tools.sh` clones and deploys it the same way it deploys
`agent-session-manager` and `notify`; bootstrap-home itself no longer owns
any of that logic or touches `~/.codex/config.toml`.

That project's own build-script convention still applies wherever it's
developed: Codex patch/build/deploy work is encoded as one deterministic,
idempotent, quiet shell script, with verbose compiler output captured in a log
and only milestones plus the final result printed — never driven through
repeated tool polling or streamed through the model.
