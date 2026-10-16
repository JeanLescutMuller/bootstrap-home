# Shift+Enter in Claude Code over SSH

Shift+Enter inserts a newline in Claude Code on the Mac and inside tmux everywhere, but submits the prompt in Claude Code run over plain SSH on the VM (no tmux). Investigated 2026-08-22, decision: no fix, use Ctrl+J there. Moved here on 2026-10-16 from the folder `~/dev/terminal-key-mapping` (its notes `CONTEXT.md`, `claude_shift_enter_diagnostic.md`, `RESOLUTION.md`), deleted after.

## What to do

| Where | New line in the prompt |
|---|---|
| Mac, any terminal Claude knows (iTerm2…) | Shift+Enter |
| inside tmux, Mac or VM | Shift+Enter (needs the `extended-keys` lines of [`files/tmux.conf`](../files/tmux.conf), deployed by `bootstrap.sh`) |
| VM over plain SSH, no tmux | **Ctrl+J**, or `\` then Enter |

## Why

| Step | |
|---|---|
| 1 | In the classic terminal protocol Enter and Shift+Enter both send one byte, CR (`0d`): no modifier bit. |
| 2 | A program can ask the terminal for extended keys (xterm `modifyOtherKeys`, or `CSI u`); then Shift+Enter arrives as `ESC[27;2;13~` (or `ESC[13;2u`), `2` = Shift, `13` = Enter. |
| 3 | Claude Code asks for it only when it recognizes the terminal, partly from `TERM_PROGRAM=iTerm.app`. |
| 4 | iTerm2 sets `TERM_PROGRAM` in the shells it starts. Over SSH the shell is started by `sshd`, which passes only `TERM` (part of the pty request) and the variables in both the client's `SendEnv` and the server's `AcceptEnv`. Debian accepts `LANG LC_*`, so `LC_TERMINAL=iTerm2` arrives, `TERM_PROGRAM` does not. |
| 5 | tmux negotiates extended keys itself, whatever `TERM_PROGRAM` says, so Claude inside tmux works over SSH too. |

A shell's `xxd` test always shows `0a` whatever is pressed: in cooked tty mode `ICRNL` turns CR into LF before the program reads it. Only a raw-mode probe (below) shows the real bytes.

## Measured (2026-08-22, `modifyOtherKeys` reset between cases)

`ESC[27;2;13~` = `1b 5b 32 37 3b 32 3b 31 33 7e`.

| Environment | Mac: Enter | Mac: Shift+Enter | VM over SSH: Enter | VM over SSH: Shift+Enter |
|---|---|---|---|---|
| bare terminal | `0d` | `0d` (same) | `0d` | `0d` (same) |
| Claude | `0d` | `ESC[27;2;13~` | `0d` | **`0d` (same)** |
| tmux | `0d` | `ESC[27;2;13~` | `0d` | `ESC[27;2;13~` |
| tmux + Claude | `0d` | `ESC[27;2;13~` | `0d` | `ESC[27;2;13~` |

Confirmed: `TERM_PROGRAM=iTerm.app claude` on the VM, outside tmux, makes Shift+Enter insert a newline.

## Decision: no fix (2026-08-22)

Anthropic closed this exact bug as "not planned": [anthropics/claude-code#16859](https://github.com/anthropics/claude-code/issues/16859). Their docs give Ctrl+J and `\` + Enter as the newline keys that work in every terminal: [terminal-config](https://code.claude.com/docs/en/terminal-config).

| Rejected fix | Why |
|---|---|
| export `TERM_PROGRAM=iTerm.app` on the VM (a `claude` wrapper, or only in iTerm2 SSH sessions) | tells Claude something false; a later release may switch on more iTerm2-only features from it (clipboard, images) where they don't work |
| `SendEnv TERM_PROGRAM` on the Mac + `AcceptEnv` in the VM's `sshd_config` | same false claim, plus a root change on the VM |
| a Claude keybinding | nothing to bind: over plain SSH both keys arrive as the same byte |

Nothing was changed on either machine for this.

## Codex inside tmux (2026-10)

tmux sends Shift+Enter as `ESC[27;2;13~` by default, which Codex CLI 0.150.1 reads as submit. `files/tmux.conf` sets `extended-keys-format csi-u` (`ESC[13;2u`), which both Claude and Codex read as Shift+Enter.

## Check again after a Claude Code, Codex or tmux update

Run [`tools/terminal_key_probe.py`](../tools/terminal_key_probe.py) by hand on each machine, directly in an interactive terminal (not through an agent). It prompts for Enter and Shift+Enter in six environments (bare terminal, Claude, tmux, tmux + Claude, Codex, tmux + Codex) and prints the byte table above for this machine:

```bash
python3 ~/dev/my-setup/tools/terminal_key_probe.py                       # on the Mac
scp ~/dev/my-setup/tools/terminal_key_probe.py H-Frank-1:/tmp/ && \
  ssh -t H-Frank-1 'python3 /tmp/terminal_key_probe.py'                  # on the VM, over plain SSH
```

If "Claude" over SSH turns DISTINCT, Claude Code has fixed it upstream and Shift+Enter works on the VM too.
