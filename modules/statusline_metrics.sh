#!/bin/bash
# Installs glances and schedules statusline-glances-poll.sh to sample
# CPU/memory every 30s into the shared statusline cache - see
# files/statusline-glances-poll.sh and the "Cache layout" section of
# files/statusline-command.md for why this exists.
#
# Deliberately NOT in the default MODULES list (bootstrap.sh) - unlike
# the other modules, this one installs new third-party software (glances)
# and registers a persistent background scheduler, so it only runs where
# explicitly targeted: `INSTALL=true bash bootstrap.sh statusline_metrics`.
step "statusline metrics (glances poller)"

BIN_NAME="statusline-glances-poll"
BIN_PATH="$HOME/.local/bin/$BIN_NAME"

if ! command -v glances >/dev/null 2>&1; then
    if [ "$INSTALL" = "true" ]; then
        if command -v brew >/dev/null 2>&1; then
            brew install glances >/dev/null 2>&1 && installed "glances (brew)" || fail "glances (brew install failed)"
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y glances >/dev/null 2>&1 && installed "glances (apt)" || fail "glances (apt install failed)"
        else
            fail "glances (no brew or apt-get found - install manually)"
        fi
    else
        skip "glances (not installed)"
    fi
else
    ok "glances"
fi

if [ "$(uname -s)" = "Darwin" ]; then
    PLIST="$HOME/Library/LaunchAgents/com.bootstrap-home.statusline-glances-poll.plist"
    DESIRED_PLIST=$(cat <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.bootstrap-home.statusline-glances-poll</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN_PATH</string>
    </array>
    <key>StartInterval</key>
    <integer>30</integer>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.claude/statusline-caches/glances-poll.err</string>
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
PLISTEOF
)

    if [ -f "$PLIST" ] && [ "$(cat "$PLIST")" = "$DESIRED_PLIST" ]; then
        ok "launchd job (com.bootstrap-home.statusline-glances-poll)"
    elif [ "$INSTALL" = "false" ]; then
        skip "launchd job (com.bootstrap-home.statusline-glances-poll)"
    else
        launchctl unload "$PLIST" >/dev/null 2>&1 || true
        mkdir -p "$(dirname "$PLIST")"
        printf '%s' "$DESIRED_PLIST" > "$PLIST"
        launchctl load "$PLIST" 2>/dev/null
        installed "launchd job (com.bootstrap-home.statusline-glances-poll, every 30s)"
    fi
else
    # Linux (Debian VM): systemd --user timer instead of launchd.
    UNIT_DIR="$HOME/.config/systemd/user"
    SERVICE="$UNIT_DIR/statusline-glances-poll.service"
    TIMER="$UNIT_DIR/statusline-glances-poll.timer"

    DESIRED_SERVICE=$(cat <<SERVICEEOF
[Unit]
Description=Sample CPU/memory into the statusline cache

[Service]
Type=oneshot
ExecStart=$BIN_PATH
SERVICEEOF
)
    DESIRED_TIMER=$(cat <<TIMEREOF
[Unit]
Description=Run statusline-glances-poll every 30s

[Timer]
OnBootSec=10
OnUnitActiveSec=30
AccuracySec=5

[Install]
WantedBy=timers.target
TIMEREOF
)

    if [ -f "$SERVICE" ] && [ "$(cat "$SERVICE")" = "$DESIRED_SERVICE" ] \
        && [ -f "$TIMER" ] && [ "$(cat "$TIMER")" = "$DESIRED_TIMER" ]; then
        ok "systemd --user timer (statusline-glances-poll)"
    elif [ "$INSTALL" = "false" ]; then
        skip "systemd --user timer (statusline-glances-poll)"
    else
        mkdir -p "$UNIT_DIR"
        printf '%s' "$DESIRED_SERVICE" > "$SERVICE"
        printf '%s' "$DESIRED_TIMER" > "$TIMER"
        systemctl --user daemon-reload
        systemctl --user enable --now statusline-glances-poll.timer >/dev/null 2>&1
        installed "systemd --user timer (statusline-glances-poll, every 30s)"
    fi
fi
