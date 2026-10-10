---
name: services
description: How services and scheduled jobs are created, changed, renamed and decommissioned on this user's machines (MacBook, VM H-Frank-1, GCP). Use whenever creating, changing, renaming, moving or removing a service, a scheduled or recurring job, a LaunchAgent or plist, a systemd service or timer, a cron job or a Cloud Scheduler entry, or an install.sh / uninstall.sh that installs one.
---

# Services and scheduled jobs

| Word | Meaning |
|---|---|
| **Job** | one thing to run on a schedule (job-runner's word) |
| **Trigger** | the machine's own scheduler entry that starts it: LaunchAgent, systemd timer, Cloud Scheduler |
| **Service** | something that runs all the time (`KeepAlive` / `Restart=always`) |
| **job-runner** | `~/dev/job-runner`: the Bash library (`~/opt/job-runner/lib.sh`) a job's **entrypoint** sources: records each check's status, runs the work with a timeout, helps decide when to skip; every status shows on the phone dashboard `http://h-frank-1:8097` |
| **Entrypoint** | the job's own Bash script, `~/opt/<repo>/entrypoint.sh` (or `<job>.sh`), run by its trigger |

## Rules, always

- **Development on the Mac only**; the VM and GCP are deploy targets. Never edit code on the VM.
- **Real files in `~/opt/<repo>/`**: code, state, logs and the trigger files themselves. The OS folders hold only symlinks into it: `~/Library/LaunchAgents/<name>.plist`, `~/.config/systemd/user/<name>.{service,timer}`; `~/.local/bin/` too.
- **Name `com.jeanlescut.<repo>[.<job>]`**: `<repo>` exactly as on GitHub (`git remote -v`), `.<job>` only when the project has several; the same name on every machine; the launchd `Label` is the file name.
- **User scope only**: never `/etc/systemd/system/`, `/Library/LaunchDaemons/` or a root crontab unless the job truly needs root (ask the user first). The VM has no cron installed: use systemd timers.
- **The project's `install.sh` writes its triggers**: idempotent and self-migrating (it removes its own former names and files). Linux: `loginctl enable-linger "$USER"` best-effort.
- **Secrets** in `~/.config/<repo>/*.env` (`chmod 600`), read by the command; never in a plist, unit or job file, never printed, logged or committed. GCP: Secret Manager.
- **Schedules in UTC.**
- **Another project's trigger runs in production**: change it only with the user's OK; show the diff first; one machine at a time.

## 1. Which kind?

```
runs all the time (server, receiver, watcher) ──► a service, no job-runner                    (§3)
anything recurring (a poller included) ───────────► a job: a trigger runs its entrypoint        (§2)
```

## 2. A job through job-runner

1. Read `~/dev/job-runner/DESIGN.md` §4 (the settings and helpers) and copy the closest entrypoint from `~/dev/job-runner/examples/` (one per real job, its requirements in its header) into the project as `src/entrypoint.sh` (or `src/<job>.sh` when the project has several jobs). The simplest is two lines: `. ~/opt/job-runner/lib.sh` then `jr_execute TIMEOUT_MIN CMD…`; add rules only for a real constraint (`jr_skip_if SUCCESS day "…"`, `jr_claim MIN` against overlap, `JR_SYNC_ENV=VM|GITHUB` + `jr_pull` for a job shared by several machines).
2. The command returns real exit codes (0 only when the work is done); any other code is the project's own, mapped in the entrypoint (`jr_write_status WAIT|SKIP …`).
3. `install.sh` copies it to `~/opt/<repo>/entrypoint.sh` and writes the triggers (on the Mac always a tick); each trigger runs `/bin/bash ~/opt/<repo>/entrypoint.sh`. A model: `~/dev/agent-session-manager/install.sh`.
4. Test one check by hand with `JR_DRY_RUN=1 /bin/bash ~/opt/<repo>/entrypoint.sh` (decides for real, does not work), then read `~/opt/job-runner/status/<job>/<machine>.tsv` and the job's card on the dashboard. Its thresholds and look: an optional `~/dev/job-runner/dashboard/conf/<repo>[.<job>].conf` (DESIGN §11).

The job's name is the entrypoint's place: `~/opt/<repo>/entrypoint.sh` → `<repo>`, `~/opt/<repo>/<job>.sh` → `<repo>.<job>`. Do not edit job-runner from another project: report a gap to the user.

## 3. Trigger files (a job's, or a service's)

Same rules and names. A working model: the trigger part of `~/dev/agent-session-manager/install.sh` (a LaunchAgent on the Mac, a systemd timer on the VM); change only these:

| | macOS plist | systemd `--user` |
|---|---|---|
| every N s | `StartInterval` N, `RunAtLoad` true | `.timer`: `OnUnitActiveSec=N`, `Persistent=true`, `WantedBy=timers.target`; `.service`: `Type=oneshot` |
| at fixed times | (the Mac may sleep: prefer a tick) | `.timer`: `OnCalendar=… UTC`, `Persistent=true` |
| all the time | `KeepAlive` true, `RunAtLoad` true | `.service`: `Restart=always`, `[Install] WantedBy=default.target` |
| load | `launchctl bootout gui/$(id -u)/$NAME; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$NAME.plist` | `systemctl --user daemon-reload && systemctl --user enable --now $NAME.timer` (or `.service`) |

## 4. Change or rename

- A new trigger name: `install.sh` removes the old one on every machine (`rm_trigger OLD_NAME` from `install_snippet.sh`), then installs the new one.
- A job's name changes (its folder or entrypoint renamed): once the old triggers are gone, mark the old name `DECOMMISSIONED=1` in `~/dev/job-runner/dashboard/conf/<old job>.conf` (then `~/dev/job-runner/deploy/deploy.sh vm`).

## 5. Decommission

1. Remove the trigger on every machine it runs on, with the project's `uninstall.sh` (or `install.sh`): macOS `launchctl bootout` + remove the link and the real file; Linux `systemctl --user disable --now`, remove links and files, `daemon-reload`; GCP the Cloud Scheduler entry and the Cloud Run job.
2. A job: `DECOMMISSIONED=1` in `~/dev/job-runner/dashboard/conf/<job>.conf`, deployed with `~/dev/job-runner/deploy/deploy.sh vm`: it folds to "Decommissioned" at the bottom of the dashboard.
3. Keep the data (`~/opt/<repo>/data`, `~/opt/job-runner/status/<job>`, `~/opt/job-runner/logs/<job>`) unless the user says to delete it.
4. Remove the trigger from the project's docs.

## 6. Check (Mac, then `ssh H-Frank-1 bash -s` with the same lines)

```bash
for d in ~/Library/LaunchAgents ~/.config/systemd/user; do [ -d "$d" ] || continue
  for f in "$d"/*.plist "$d"/*.service "$d"/*.timer; do [ -e "$f" ] || [ -L "$f" ] || continue
    n=${f##*/}; [ -L "$f" ] || { echo "real file (only apps' own are expected): $n"; continue; }
    [ -e "$f" ] || echo "broken link: $n"
    case $(readlink "$f") in "$HOME"/opt/*) ;; *) echo "link not into ~/opt: $n -> $(readlink "$f")";; esac
    case $n in com.jeanlescut.*) ;; *) echo "name not com.jeanlescut.*: $n";; esac
  done; done
```

Silence, apart from apps' own real files (Google, Steam), means every trigger follows the rules. On the VM also: `systemctl --user --failed` empty, and none of the user's files in `/etc/systemd/system/`.
