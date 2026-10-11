# General conventions (MacBook + Debian VM)

## Answering the user (interactive sessions)

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
- Plain words only: never "wholesale" or a word the user would have to decode.

### Numbers, files and commands

- Explain a method, formula or test with one tiny worked example: a table of concrete numbers.
- Before comparing numbers, name each series once in a table and use only those names; every number says its unit (per trade, day, cycle…) and its statistic (max, median, sum…); gaps are relative (%), absolute values only as a footnote.
- Token counts also as a % of Claude's window (1,000,000) and Codex's (258,400), 2 decimals; an inventory puts "at init" and "on use" in separate columns.
- Name every script, notebook or file by its full path, and say which data it reads and writes.
- A command for the user to run: the remote part of `ssh host '…'` is always single-quoted, or the Mac's shell expands `~` and `$` first.

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

# Folders

- `~/dev/<repo>` — all source repos, flat; the folder name is the real GitHub repo name (`git remote -v`).
- `~/opt/<repo>/` — only what a scheduler runs unattended, with its logs and state; the OS scheduler folders and `~/.local/bin/` hold only symlinks into it. Anything run by hand stays in `~/dev`.
- Never leave the shell's working directory changed after a spontaneous `cd` — change back before finishing, or ask first. The statusline's git-status segment reads the shell's live cwd, so a stray `cd` breaks it for the rest of the session, not just that command.

# Development vs deployment

Development (writing/editing code) happens on the MacBook only. The Debian VM, and any cloud targets, are deployment/runtime destinations — never write or edit code there directly. Which machine(s) a given project actually deploys to varies per-project (MacBook only, VM only, both, sometimes cloud too) — don't assume, check that project's own docs.

# Machine-specific

- **macOS → Debian VM**: reachable via `ssh H-Frank-1` (alias in `~/.ssh/config`; Hostinger EC2, Debian 12). Setup/provisioning details live in `bootstrap-vm`, not here.
- **macOS → home NAS**: reachable via `ssh babisnas` (alias in `~/.ssh/config`, key `~/.ssh/id_babisnas`, user `enrices`; UGREEN DXP4800 Plus, UGOS Pro = Debian 12). Home LAN only, not exposed to the internet (verified 2026-10-10). Data: `/volume1/shared_raid1` (RAID1, 901G), `/volume2/shared_nvme1` (443G). `sudo` needs a password, so ask the user for root tasks.
- **Debian VM**: `~/opt/` (user's own tools) is distinct from root-owned `/opt/` (root-run systemd services, e.g. `/opt/auto-commit` as of 2026-08-24 — being migrated to user-scope `~/opt/` + `systemd --user`, since root/system scope should be the exception, not the default).

## Machine name

Get "this machine's name" (`chan-lescut-macbook-pro`, `H-Frank-1`, `GCP`) only with the snippet in skill `machine-name` — never `hostname` or `socket.gethostname()`.

# Shared projects

Reuse these instead of rebuilding them; read the named file before depending on one. Never edit another project's repo from a session working on a different one: report the gap to the user.

| Project (`~/dev/…`) | What it gives the others | Read |
|---|---|---|
| `bootstrap-home` | Mac/home setup: dotfiles, shared skills, this file | README |
| `bootstrap-vm` | provisioning of the VM `H-Frank-1` | README |
| `job-runner` | the wrapper for every scheduled job, statuses on a phone dashboard | DESIGN.md |
| `agent-statusline` | Claude/Codex status line and its shared cache `~/opt/agent-statusline/state` | README |
| `agent-usage-tracker` | quota %, tokens and $ for Claude and Codex, per machine | `FOR_READERS.md` |
| `agent-session-manager` (`asm`) | session search, sync and resume across machines and agents | README |
| `agent-notify` | terminal notifications for concurrent sessions | README |

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

# Working rules

- Delete named files one at a time, by literal path, as their own step after looking at them; never `rm` a glob or a variable path, never inside a long command chain.
- Design: propose removals before additions; a new parameter names the step that owns it and the measurement that justifies it; measured values over hard-coded constants.
- Time fields are `ts` (Unix epoch seconds) and `dt` (ISO 8601 UTC), first in every row, table or schema.
- The ntfy phone topic is for defcon-alert alarms only: never send anything to it, not even a test, unless the user asks in that very message.
