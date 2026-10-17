#!/bin/bash
# Remote Control service (macOS only), a LaunchAgent (KeepAlive):
#
#   com.jeanlescut.my-setup.remote-control  ~/opt/my-setup/remote_control.sh (from files/)
#       keeps `claude remote-control` running, so a Claude session on this Mac
#       can be started from the phone at any time. The Mac must be awake.
#
# Real plist in ~/opt/my-setup/, linked from ~/Library/LaunchAgents/.
# Log: ~/opt/my-setup/logs/remote-control.log.
# Restarted only when its script or plist changed: a restart ends every
# session open from the phone (including the one running this, if any).
# Turning /rc on in a running session is cc-rc's job (files/cc_rc.py), run by an agent.

step "remote control service"

# $1 label, $2 source in files/, $3 interpreter
_rc_service() {
    local label="$1" src="$SCRIPT_DIR/files/$2" interp="$3"
    local opt="$HOME/opt/my-setup" script="$HOME/opt/my-setup/$2"
    local plist="$opt/$label.plist" link="$HOME/Library/LaunchAgents/$label.plist"
    local body="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>$interp</string><string>$script</string></array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>60</integer>
</dict></plist>"

    if diff -q "$src" "$script" >/dev/null 2>&1 \
        && [ "$(cat "$plist" 2>/dev/null)" = "$body" ] \
        && [ -L "$link" ] && [ "$(readlink "$link")" = "$plist" ] \
        && launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
        ok "LaunchAgent $label"
    elif [ "$INSTALL" = "false" ]; then
        skip "LaunchAgent $label"
    else
        mkdir -p "$opt/logs" "$HOME/Library/LaunchAgents"
        cp "$src" "$script"
        printf '%s\n' "$body" > "$plist"
        ln -sfn "$plist" "$link"
        launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
        if launchctl bootstrap "gui/$(id -u)" "$link"; then
            installed "LaunchAgent $label"
        else
            fail "LaunchAgent $label: launchctl bootstrap failed"
        fi
    fi
}

if [ "$(uname)" != Darwin ]; then
    ok "not macOS - skipped"
else
    # Migration: until 2026-10-17 the remote-control service was com.jeanlescut.my-setup.
    _rc_old="com.jeanlescut.my-setup"
    if [ "$INSTALL" = "true" ] && { [ -L "$HOME/Library/LaunchAgents/$_rc_old.plist" ] || [ -f "$HOME/opt/my-setup/$_rc_old.plist" ]; }; then
        launchctl bootout "gui/$(id -u)/$_rc_old" 2>/dev/null || true
        [ -L "$HOME/Library/LaunchAgents/$_rc_old.plist" ] && rm "$HOME/Library/LaunchAgents/$_rc_old.plist"
        [ -f "$HOME/opt/my-setup/$_rc_old.plist" ] && rm "$HOME/opt/my-setup/$_rc_old.plist"
        installed "removed old LaunchAgent $_rc_old"
    fi
    # Migration: the rc-links link server (2026-10-17, same day) gave way to cc-rc, run by an agent.
    _rc_old="com.jeanlescut.my-setup.rc-links"
    if [ "$INSTALL" = "true" ] && { [ -L "$HOME/Library/LaunchAgents/$_rc_old.plist" ] || [ -f "$HOME/opt/my-setup/$_rc_old.plist" ]; }; then
        launchctl bootout "gui/$(id -u)/$_rc_old" 2>/dev/null || true
        [ -L "$HOME/Library/LaunchAgents/$_rc_old.plist" ] && rm "$HOME/Library/LaunchAgents/$_rc_old.plist"
        [ -f "$HOME/opt/my-setup/$_rc_old.plist" ] && rm "$HOME/opt/my-setup/$_rc_old.plist"
        [ -f "$HOME/opt/my-setup/rc_links.py" ] && rm "$HOME/opt/my-setup/rc_links.py"
        [ -f "$HOME/.config/my-setup/rc-links.env" ] && rm "$HOME/.config/my-setup/rc-links.env"
        installed "removed old LaunchAgent $_rc_old, its script and its secret code"
    fi
    _rc_service com.jeanlescut.my-setup.remote-control remote_control.sh /bin/bash
fi
