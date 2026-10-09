# General conventions (MacBook + Debian VM)

## Communication: optimize for speed

The user has limited time, reads quickly, and does not read long prose. Make
responses easy to scan and act on:

- Keep answers short and lead with the result or next action.
- When providing commands or code to execute, consolidate them into a single
  copy-pasteable code block whenever practical.

### Show, don't narrate

**Default to a table or an ASCII/UTF-8 diagram, not paragraphs.** Prose is the
fallback, used only for something a picture genuinely cannot carry. In practice:

- A comparison, a list of values, a before/after → **a table**.
- A sequence, a pipeline, a hierarchy, a shape over time → **an ASCII/UTF-8
  diagram** (box-drawing characters, a sparkline, a small bar chart of `█`).
- A trend or distribution in real data → **a plot**, written to a PNG and shown,
  or a text sparkline if that is enough.
- Never a wall of prose explaining numbers that could have been a table.

Aim for **at most 2–3 short sentences between visuals**. If a response is turning
into paragraphs, that is the signal to stop and draw it instead.

### Vocabulary: the user's words, defined once, never changed

The user has repeatedly been lost by invented terminology. Therefore:

- **Use the user's own words** for the things they named. If they say "window",
  do not start saying "envelope" or "interval".
- **Do not coin a new term** when an ordinary phrase works. If a new term is
  genuinely needed, define it **in one line, in a table**, the first time it
  appears, and never silently replace it later.
- **Keep the vocabulary small and stable.** One concept = one word, for the whole
  project and the whole conversation. Renaming a concept mid-thread is a bug.
- When using a project-specific term in a reply, assume the user does **not**
  remember it: re-gloss it in a few words (`amount_due` (how much to spend now)).

### Re-orienting after a gap

The user often leaves a conversation and returns days later, with no memory of
where it stood. **At the start of a session, check how long it has been since the
previous exchange** (file mtimes, `git log -1 --format=%cd`, the last entry in a
log or state file).

If it has been more than roughly a day, open with a compact re-orientation
**before** doing anything else — graphical, not narrative:

- how long it has been, and the date of the last work;
- a one-line reminder of the project's goal, in the user's words;
- the overall design as a small diagram (the stages/components and where we are);
- a table of what is **done** / **in progress** / **next**;
- the single open question or decision that is waiting on them, if any.

Keep the whole thing to a screenful. It is a map, not a report.

- `~/dev/` — all source repos, flat (no category subfolders).
- `~/opt/<project>/` — deployed **and scheduled** runtime copy: what a launchd job / systemd unit / cron actually points at, plus the log/state/data it produces. Separate from the git source in `~/dev/<project>`. Everything that scheduled thing owns lives here as a real file — code, logs, state, and the scheduler/trigger definition itself (LaunchAgent `.plist`, systemd `.service`/`.timer`). The OS-mandated location (`~/Library/LaunchAgents/`, `~/.config/systemd/user/`) holds only a symlink pointing back into `~/opt/<project>/` — never a real file there. Ad-hoc, run-by-hand tooling (a one-off script, exploratory analysis, a recompute/migration helper) stays in `~/dev/<project>` and runs from there, even when it reads or writes that project's live `~/opt/` state — don't duplicate it into `~/opt/` just because it touches production data. `~/opt/` is for what a scheduler runs unattended, not for anything a human runs by hand.
- `~/.local/bin/` — symlinks into `~/opt/<project>/`, never real files. Same symlink-only rule as the scheduler files above.
- `~/dev/<x>` folder name must match the real GitHub repo name (check `git remote -v`, don't assume) — a drifted `~/opt/` copy name doesn't override this.
- Never leave the shell's working directory changed after a spontaneous `cd` — change back before finishing, or ask first. The statusline's git-status segment reads the shell's live cwd, so a stray `cd` breaks it for the rest of the session, not just that command.

# Development vs deployment

Development (writing/editing code) happens on the MacBook only. The Debian VM, and any cloud targets, are deployment/runtime destinations — never write or edit code there directly. Which machine(s) a given project actually deploys to varies per-project (MacBook only, VM only, both, sometimes cloud too) — don't assume, check that project's own docs.

# Machine-specific

- **macOS → Debian VM**: reachable via `ssh H-Frank-1` (alias in `~/.ssh/config`; Hostinger EC2, Debian 12). Setup/provisioning details live in `bootstrap-vm`, not here.
- **Debian VM**: `~/opt/` (user's own tools) is distinct from root-owned `/opt/` (root-run systemd services, e.g. `/opt/auto-commit` as of 2026-08-24 — being migrated to user-scope `~/opt/` + `systemd --user`, since root/system scope should be the exception, not the default).

# Monitoring

- **Statusline shared data**: Claude and Codex use the lazy cache under
  `~/opt/agent-statusline/state` (deployed by the independent `agent-statusline`
  project, not bootstrap-home). A renderer reads cached hostname, Git, and
  memory data; when dynamic data is stale, only the renderer that atomically
  acquires its shared lock performs the bounded refresh. Other sessions
  immediately keep displaying the previous value. Usage tracking (quota
  percent, tokens, spend, for both Claude and Codex) is a separate project,
  `agent-usage-tracker` (`~/opt/agent-usage-tracker/`), split back out of
  `agent-statusline` on 2026-09-30 (it had absorbed the former
  `agent-quota-tracker` on 2026-08-31). Claude's primary quota path is free:
  every Claude render pipes its stdin payload (which carries live
  `rate_limits`) into the tracker's `bin/ingest-claude-statusline.sh`, and
  the statusline displays the tracker's `state/quota/claude` (the account's
  freshest reading); a LaunchAgent-scheduled poller is only a fallback for a
  session that hasn't sent its first message yet or a machine-wide idle
  stretch. Codex relies on its own scheduled poller plus Codex's local
  session files. Either project works without the other. See
  `agent-usage-tracker`'s README ("Contract with agent-statusline").

# Scheduling recurring jobs

Standard pattern for any recurring background job under `~/dev/`: a LaunchAgent (macOS) or a systemd `--user` service+timer (Linux), named `com.jeanlescut.<repo>[.<job>]` — `<repo>` the GitHub repo name, `.<job>` only when the project has several jobs, the same name on every machine. Real files in `~/opt/<repo>/`, symlinks in `~/Library/LaunchAgents/<name>.plist` or `~/.config/systemd/user/<name>.{service,timer}`, with `loginctl enable-linger` (best-effort) on Linux so the user unit runs without an active login session. Never system scope (`/etc/systemd/system/`, `/Library/LaunchDaemons/`, root cron) unless the job truly needs root. A project's `install.sh` removes its former trigger names itself (self-migrating).

# Keeping this file in sync

When modifying this file, always consider modifying the bootstrap template at
`~/dev/bootstrap-home/files/home_AGENTS.md` too, so the change persists across
machines (this file is the deployed copy; that one is the source template).

# Token-conscious execution

The user of this machine has very few tokens available. For any job that might
be long-running or will likely be repeated (building a binary, testing a whole
project, deploying or installing something, etc.), always prefer writing a
reusable bash script and executing it with stdout/stderr redirected to files,
rather than streaming output through the model or driving the process step by
step via the LLM. Inspect the log files afterward only as needed (e.g. tail on
failure). Minimize token consumption wherever possible.
