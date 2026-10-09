---
name: services
description: How services and scheduled jobs are created, changed, renamed and decommissioned on this user's machines (MacBook, VM H-Frank-1, GCP). Use whenever creating, changing, renaming, moving or removing a service, a scheduled or recurring job, a LaunchAgent or plist, a systemd service or timer, a cron job or a Cloud Scheduler entry, or an install.sh / uninstall.sh that installs one.
---

# Services and scheduled jobs

| Word | Meaning |
|---|---|
| **Job** | one thing to run on a schedule (multi-host-orchestrator's word) |
| **Trigger** | the machine's own scheduler entry that starts it: LaunchAgent, systemd timer, Cloud Scheduler |
| **Service** | something that runs all the time (`KeepAlive` / `Restart=always`) |
| **mho** | multi-host-orchestrator (`~/dev/multi-host-orchestrator`): runs a job's checks, records them, shows them on the phone dashboard `http://h-frank-1:8098` |

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
runs all the time (server, receiver, watcher) ─────────────► a service: no mho                       (§3)
every few minutes, a missed run is harmless (a poller) ────► a plain trigger to the command: no mho   (§3)
anything else recurring: daily, retries, conditions, ──────► a job through mho                        (§2)
several machines, must show on the dashboard
```

## 2. A job through mho

1. Read `~/dev/multi-host-orchestrator/doc/examples.md` ("Decide in this order": machines → trigger → period → extra rules); copy the closest `examples/NN-*/mho_var.sh` into the project as `src/mho_var.sh`, keeping only the options a constraint asks for.
2. The command returns real exit codes (0 only when the work is done); `TIMEOUT_MIN` always.
3. `install.sh` copies it to `~/opt/<repo>/mho_var.sh` and writes the triggers with `examples/triggers/install_snippet.sh` (`mac_tick SECONDS`, `vm_tick SECONDS`, `vm_fixed 'OnCalendar'…`; on the Mac always a tick). Each trigger runs `~/opt/multi-host-orchestrator/mho_entrypoint.sh ~/opt/<repo>/mho_var.sh`.
4. Test one check by hand (that command), then read `~/opt/multi-host-orchestrator/state/<job>/records.tsv` and the job's card on the dashboard.

The job's name is the folder holding `mho_var.sh` (or `<job>.env`'s file name). Moving an existing schedule to mho, and GCP: `~/dev/multi-host-orchestrator/doc/migrating_a_project.md`. Do not edit multi-host-orchestrator from another project: report a gap to the user.

## 3. A plain trigger or a service (no mho)

Same rules and names. Start from `install_snippet.sh` and change only these:

| | macOS plist | systemd `--user` |
|---|---|---|
| every N s | `StartInterval` N, `RunAtLoad` true | `.timer`: `OnUnitActiveSec=N`, `Persistent=true`, `WantedBy=timers.target`; `.service`: `Type=oneshot` |
| at fixed times | (the Mac may sleep: prefer a tick) | `.timer`: `OnCalendar=… UTC`, `Persistent=true` |
| all the time | `KeepAlive` true, `RunAtLoad` true | `.service`: `Restart=always`, `[Install] WantedBy=default.target` |
| load | `launchctl bootout gui/$(id -u)/$NAME; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$NAME.plist` | `systemctl --user daemon-reload && systemctl --user enable --now $NAME.timer` (or `.service`) |

## 4. Change or rename

- A new trigger name: `install.sh` removes the old one on every machine (`rm_trigger OLD_NAME` from `install_snippet.sh`), then installs the new one.
- A mho job's name changes (its folder or file renamed): once the old triggers are gone, `~/dev/multi-host-orchestrator/dev/decommission.sh OLD_JOB`.

## 5. Decommission

1. Remove the trigger on every machine it runs on, with the project's `uninstall.sh` (or `install.sh`): macOS `launchctl bootout` + remove the link and the real file; Linux `systemctl --user disable --now`, remove links and files, `daemon-reload`; GCP the Cloud Scheduler entry and the Cloud Run job.
2. A mho job: `~/dev/multi-host-orchestrator/dev/decommission.sh JOB` moves it to "Decommissioned" at the bottom of the dashboard.
3. Keep the data (`~/opt/<repo>/data`, `~/opt/multi-host-orchestrator/state/<job>`, the VM's `hub/<machine>/<job>`) unless the user says to delete it.
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
