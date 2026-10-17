---
name: claude-sessions-overview
description: Show every tmux session on this Mac and the Claude sessions running in each, with agent-notify's color icon, as tappable links that turn on Remote Control (/rc) in a session. Use when the user types /claude-sessions-overview, or asks to see, list or map their Claude sessions or tmux sessions, especially from the phone.
---

# Claude sessions overview

1. Run `cc-map` (no argument; `~/.local/bin/cc-map`, from `~/dev/my-setup/files/cc_map.py`).
2. Reply with its output exactly as printed, as Markdown: **never inside a code block**, or the links stop being tappable on the phone. Add nothing before it; after it, at most one line: `📱 = Remote Control on · tap a name to turn it on`.
3. If `cc-map` is not found or prints nothing, say so in one line: it is installed by `INSTALL=true bash ~/dev/my-setup/bootstrap.sh`.

Never type into a tmux pane yourself (`tmux send-keys`) to turn on /rc: the links do it, through the `rc-links` service (`~/opt/my-setup/rc_links.py`), which first checks that the session is idle and its prompt box empty.

What the icons mean, if asked: 🔵 working · 🟡 waiting for the user · 🟢 done, not seen yet · ⚪ done, seen · 🟣 on hold · ⚫ no icon in agent-notify (acknowledged, or not tracked). The links work on the home Wi-Fi only.
