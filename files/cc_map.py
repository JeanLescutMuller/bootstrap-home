#!/usr/bin/env python3
"""cc-map: draw every tmux session, its panes, and the Claude session running in each.

Reads `tmux list-panes -a`, ~/.claude/sessions/<pid>.json (one per live Claude process), agent-notify's
state, and the rc-links code in ~/.config/my-setup/rc-links.env. Writes nothing.
Usage: cc-map [md|tree|table|boxes]
  md (default): Markdown for the phone; a session with Remote Control off is a link to rc-links
  (rc_links.py), which turns it on.
"""
import getpass, glob, json, os, subprocess, sys, time

BUSY, IDLE = "●", "○"


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def claude_sessions():
    out = []
    for f in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
        try:
            d = json.load(open(f))
        except (OSError, ValueError):
            continue
        if alive(d.get("pid", -1)):
            out.append(d)
    return out


def tmux_panes():
    fmt = "#{session_name}\t#{session_attached}\t#{window_index}\t#{pane_index}\t#{pane_id}\t#{pane_current_command}\t#{pane_pid}"
    r = subprocess.run(["tmux", "list-panes", "-a", "-F", fmt], capture_output=True, text=True)
    rows = [l.split("\t") for l in r.stdout.splitlines()]
    return [dict(sess=s, attached=a != "0", win=w, pane=p, pane_id=i, cmd=c, pane_pid=pp) for s, a, w, p, i, c, pp in rows]


# agent-notify's terminal-title icon for a pane: its state is in /tmp/agent-notify-$USER/<pane pid>/state.env,
# the icons in its renderer settings ("Agent.User" first, then "Agent"; none for Acknowledged).
NOTIFY_ICONS = os.path.expanduser("~/opt/agent-notify/app/renderers.d/terminal-title/settings.json")
NO_ICON = "⚫"


def notify_icon(pane_pid):
    try:
        icons = json.load(open(NOTIFY_ICONS))
        st = dict(l.strip().split("=", 1) for l in open(f"/tmp/agent-notify-{getpass.getuser()}/{pane_pid}/state.env") if "=" in l)
    except (OSError, ValueError, KeyError):
        return NO_ICON
    a, u = st.get("AGENT_STATE", ""), st.get("USER_STATE", "")
    return icons.get(f"{a}.{u}") or icons.get(a) or NO_ICON


def label(c):
    st = BUSY if c.get("status") == "busy" else IDLE
    where = c.get("cwd", "").replace(os.path.expanduser("~"), "~")
    age = int(time.time() - c.get("updatedAt", 0) / 1000)
    age = f"{age // 3600}h" if age >= 3600 else f"{age // 60}m"
    return st, c.get("name") or "(no name)", where, c["sessionId"][:8], age


def build():
    by_pane = {c["tmux"].split(".")[-1]: c for c in claude_sessions() if c.get("tmux")}
    others = [c for c in claude_sessions() if not c.get("tmux")]
    groups = {}
    for p in tmux_panes():
        groups.setdefault(p["sess"], []).append((p, by_pane.get(p["pane_id"])))
    return groups, others


def other_where(c):
    return "rc server (phone)" if c.get("entrypoint") == "sdk-cli" else "outside tmux"


def tree(groups, others):
    print("tmux")
    names = list(groups)
    for i, s in enumerate(names):
        last_s = i == len(names) - 1 and not others
        panes = groups[s]
        n = sum(1 for _, c in panes if c)
        print(f"{'└' if last_s else '├'}── {s}  ({n} Claude{'' if groups[s][0][0]['attached'] else ', detached'})")
        for j, (p, c) in enumerate(panes):
            pre = ("    " if last_s else "│   ") + ("└── " if j == len(panes) - 1 else "├── ")
            if c:
                st, name, where, sid, age = label(c)
                print(f"{pre}{p['pane_id']:<4} {st} {name:<38} {where:<26} {sid}  {age}")
            else:
                print(f"{pre}{p['pane_id']:<4} · {p['cmd']}")
    if others:
        print("└── (not in tmux)")
        for j, c in enumerate(others):
            st, name, where, sid, age = label(c)
            print(f"    {'└' if j == len(others) - 1 else '├'}── {st} {name:<43} {where:<26} {sid}  {other_where(c)}")
    print(f"\n{BUSY} busy  {IDLE} idle  · no Claude   (age = since last status change)")


def table(groups, others):
    rows = [(s, p["pane_id"], *label(c)) for s, ps in groups.items() for p, c in ps if c]
    rows += [("—", other_where(c), *label(c)) for c in others]
    hdr = ("tmux session", "pane", "", "Claude session", "folder", "id", "age")
    w = [max(len(str(r[i])) for r in rows + [hdr]) for i in range(len(hdr))]
    line = lambda l, m, r: l + m.join("─" * (x + 2) for x in w) + r
    fmt = lambda r: "│" + "│".join(f" {str(v):<{w[i]}} " for i, v in enumerate(r)) + "│"
    print(line("┌", "┬", "┐")); print(fmt(hdr)); print(line("├", "┼", "┤"))
    prev = None
    for r in rows:
        if prev and r[0] != prev:
            print(line("├", "┼", "┤"))
        print(fmt(r if r[0] != prev else ("",) + r[1:]))
        prev = r[0]
    print(line("└", "┴", "┘"))


def boxes(groups, others):
    for s, ps in list(groups.items()) + ([("not in tmux", [(None, c) for c in others])] if others else []):
        lines = []
        for p, c in ps:
            if c:
                st, name, where, sid, age = label(c)
                lines.append(f"{st} {name[:28]:<28} {age:>3}")
            else:
                lines.append(f"· {p['cmd']}")
        w = max(len(l) for l in lines + [s]) + 2
        print(f"╭─ {s} " + "─" * (w - len(s) - 2) + "╮")
        for l in lines:
            print(f"│ {l:<{w}}│")
        print("╰" + "─" * (w + 1) + "╯")


def md(groups, others, width=26, base=None):
    """Markdown, no code block: a bold line per tmux session, one bullet per Claude, notify's icon first.
    With base (rc_links.py's http://<ip>:<port>/<token>), a session with Remote Control off is a link that turns it on."""
    cut = lambda n: n if len(n) <= width else n[: width - 1] + "…"
    for s, ps in groups.items():
        rows = [(p, notify_icon(p["pane_pid"]), c) for p, c in ps if c]
        if not rows:
            continue
        print(f"**{s}**")
        for p, icon, c in rows:
            name = cut(c.get('name') or '(no name)')
            if c.get("bridgeSessionId"):
                name = f"{name} 📱"
            elif base:
                name = f"[{name}]({base}/rc/{p['pane_id'][1:]})"
            print(f"- {icon} {name} · {label(c)[4]}")
        print()
    if others:
        print("**not in tmux**")
        for c in others:
            print(f"- {NO_ICON} {cut(c.get('name') or '(no name)')} · {label(c)[4]}")


def rc_links_base():
    """http://<this Mac's Wi-Fi address>:<port>/<code>, or None without the code file or an address."""
    try:
        env = dict(l.strip().split("=", 1) for l in open(os.path.expanduser("~/.config/my-setup/rc-links.env")) if "=" in l)
    except OSError:
        return None
    try:
        ip = subprocess.run(["ipconfig", "getifaddr", "en0"], capture_output=True, text=True).stdout.strip()
    except OSError:  # not macOS
        return None
    return f"http://{ip}:{env.get('RC_LINKS_PORT', '8765')}/{env['RC_LINKS_TOKEN']}" if ip and "RC_LINKS_TOKEN" in env else None


style = sys.argv[1] if len(sys.argv) > 1 else "md"
if style == "md":
    md(*build(), base=rc_links_base())
else:
    {"tree": tree, "table": table, "boxes": boxes}[style](*build())
