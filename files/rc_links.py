#!/usr/bin/env python3
"""Turn on Remote Control (/rc) in a tmux-hosted Claude session from a link tapped on the phone.

GET /<token>/rc/<pane number>  ->  types `/rc` + Enter into tmux pane %<n>, only when that pane runs a
Claude session that is idle, has Remote Control off, and has an empty prompt box. Nothing else is accepted.
Run by the LaunchAgent com.jeanlescut.my-setup.rc-links (KeepAlive); cc-map prints the links.
Reads tmux, ~/.claude/sessions/*.json, agent-notify's state, and ~/.config/my-setup/rc-links.env
(RC_LINKS_TOKEN, the secret code in every link, made here on first run; RC_LINKS_PORT, default 8765).
Writes ~/opt/my-setup/logs/rc-links.log: one line per start and per tap.
"""
import getpass, glob, html, json, os, re, secrets, subprocess, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# launchd's PATH has no tmux.
os.environ["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "/usr/bin:/bin")
ENV_FILE = os.path.expanduser("~/.config/my-setup/rc-links.env")
if not os.path.exists(ENV_FILE):
    os.makedirs(os.path.dirname(ENV_FILE), exist_ok=True)
    with open(os.open(ENV_FILE, os.O_WRONLY | os.O_CREAT, 0o600), "w") as f:
        f.write(f"RC_LINKS_TOKEN={secrets.token_urlsafe(16)}\nRC_LINKS_PORT=8765\n")
ENV = dict(l.strip().split("=", 1) for l in open(ENV_FILE) if "=" in l)
TOKEN, PORT = ENV["RC_LINKS_TOKEN"], int(ENV.get("RC_LINKS_PORT", "8765"))
LOG = os.path.expanduser("~/opt/my-setup/logs/rc-links.log")
os.makedirs(os.path.dirname(LOG), exist_ok=True)


def log(msg):
    with open(LOG, "a") as f:
        f.write(f"{int(time.time())}\t{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\t{msg}\n")


def tmux(*args):
    return subprocess.run(["tmux", *args], capture_output=True, text=True)


def session_for(pane_id):
    for f in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
        try:
            d = json.load(open(f))
            os.kill(d["pid"], 0)
        except (OSError, ValueError, KeyError):
            continue
        if (d.get("tmux") or "").endswith("." + pane_id):
            return d
    return None


def notify_state(pane_id):
    pid = tmux("display", "-p", "-t", pane_id, "#{pane_pid}").stdout.strip()
    try:
        return dict(l.strip().split("=", 1) for l in open(f"/tmp/agent-notify-{getpass.getuser()}/{pid}/state.env") if "=" in l)
    except OSError:
        return {}


def prompt_text(pane_id):
    """What is typed in the prompt box: the text after the last '❯' on screen, without the grey (dim) text
    Claude shows in an empty box (an example, or its suggested next message). None if no prompt box is found."""
    lines = [l for l in tmux("capture-pane", "-e", "-p", "-t", pane_id).stdout.splitlines() if "❯" in l]
    if not lines:
        return None
    typed = re.sub(r"\x1b\[2m.*?(\x1b\[0m|$)", "", lines[-1].split("❯", 1)[1])
    return re.sub(r"\x1b\[[0-9;]*m", "", typed).replace("\xa0", " ").strip()


def turn_on(n):
    """Returns (ok, message)."""
    pane_id = f"%{n}"
    if tmux("display", "-p", "-t", pane_id, "#{pane_id}").stdout.strip() != pane_id:
        return False, f"no tmux pane {pane_id}"
    c = session_for(pane_id)
    if not c:
        return False, f"no Claude session in pane {pane_id}"
    name = c.get("name") or c["sessionId"][:8]
    if c.get("bridgeSessionId"):
        return True, f"{name}: Remote Control was already on"
    if c.get("status") != "idle" or notify_state(pane_id).get("AGENT_STATE") == "WaitingForUser":
        return False, f"{name} is busy or waiting for an answer: try again when it is idle"
    typed = prompt_text(pane_id)
    if typed is None or typed:
        return False, f"{name}: its prompt box is not empty ({typed!r}), so nothing was typed"
    tmux("send-keys", "-t", pane_id, "-l", "/rc")
    time.sleep(0.5)
    tmux("send-keys", "-t", pane_id, "Enter")
    for _ in range(20):
        time.sleep(0.5)
        c = session_for(pane_id) or {}
        if c.get("bridgeSessionId"):
            return True, f"{name}: Remote Control is on. It is now in the app's session list."
    return False, f"{name}: /rc sent, but Remote Control did not show up within 10 s"


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        parts = self.path.strip("/").split("/")
        if len(parts) != 3 or not secrets.compare_digest(parts[0], TOKEN) or parts[1] != "rc" or not parts[2].isdigit():
            self.send_response(404); self.end_headers()
            return
        ok, msg = turn_on(parts[2])
        log(f"{self.client_address[0]}\t%{parts[2]}\t{'ok' if ok else 'refused'}\t{msg}")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(f"<meta name=viewport content='width=device-width'><h1 style='font:2em system-ui'>"
                         f"{'✅' if ok else '❌'} {html.escape(msg)}</h1>".encode())

    def log_message(self, *a):
        pass


log(f"start port {PORT}")
ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
