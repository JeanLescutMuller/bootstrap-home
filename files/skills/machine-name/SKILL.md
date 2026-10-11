---
name: machine-name
description: The one rule and the two code snippets (bash, Python) that give "this machine's name" (chan-lescut-macbook-pro, H-Frank-1, GCP). Use whenever code needs the machine's or host's name - a key for stored data, a comparison, a display, a log line - instead of hostname, socket.gethostname() or platform.node().
---

# Machine name

The snippets' comment points to "Machine name" in ~/AGENTS.md, which points here: keep that comment unchanged, copies in other repos must stay identical.

**Rule:** `$JR_MACHINE_NAME` if set (containers, GCP, tests), else the OS's hand-set name — macOS `scutil --get HostName`, Linux `/etc/hostname` — cut at the first dot, case unchanged, must match `[A-Za-z0-9-]+` or it is an error (never a fallback). Today: `chan-lescut-macbook-pro`, `H-Frank-1`, `GCP`.

Every project that needs "this machine's name" (a key for stored data, a comparison with a literal, a display) copies one of these two snippets **identically**, with the comment that points here; never `hostname`, `hostname -s/-f`, `socket.gethostname()`, `platform.node()` or `LocalHostName` (Bonjour adds `-1`/`-2` by itself; with no `HostName` set, the network renames the Mac — it did three times on 2026-10-08 and split stored data).

```bash
# This machine's name: "Machine name" in ~/AGENTS.md (copy it identically)
m=${JR_MACHINE_NAME:-$(if [ "$(uname)" = Darwin ]; then scutil --get HostName; else cat /etc/hostname; fi 2>/dev/null)} || :
m=${m%%.*}; [[ $m =~ ^[A-Za-z0-9-]+$ ]] || { echo "no machine name: macOS sudo scutil --set HostName <name>; Linux sudo hostnamectl set-hostname <name>" >&2; exit 1; }
```

```python
def machine_name() -> str:
    """This machine's name: "Machine name" in ~/AGENTS.md (copy it identically)."""
    name = (os.environ.get("JR_MACHINE_NAME") or (
        subprocess.run(["scutil", "--get", "HostName"], capture_output=True, text=True).stdout
        if sys.platform == "darwin" else Path("/etc/hostname").read_text())).strip().split(".")[0]
    if not re.fullmatch(r"[A-Za-z0-9-]+", name):
        raise RuntimeError("no machine name: macOS sudo scutil --set HostName <name>; Linux sudo hostnamectl set-hostname <name>")
    return name
```

A display (status line, colour) replaces the error branch with `m='?'`. The name is fixed at provisioning: `bootstrap-home` checks the Mac's `HostName`, `bootstrap-vm` sets `/etc/hostname`. A new name for an existing machine = a migration of every store keyed by it (job-runner status/logs/dashboard conf, agent-usage-tracker `central/<machine>/` and `requests.machine`).
