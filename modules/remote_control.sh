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

if [ "$(uname)" != Darwin ]; then
    ok "not macOS - skipped"
else
    _rc_label="com.jeanlescut.my-setup.remote-control"
    _rc_script="$HOME/opt/my-setup/remote_control.sh"
    _rc_plist="$HOME/opt/my-setup/$_rc_label.plist"
    _rc_link="$HOME/Library/LaunchAgents/$_rc_label.plist"
    _rc_body="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
  <key>Label</key><string>$_rc_label</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$_rc_script</string></array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>60</integer>
</dict></plist>"

    if diff -q "$SCRIPT_DIR/files/remote_control.sh" "$_rc_script" >/dev/null 2>&1 \
        && [ "$(cat "$_rc_plist" 2>/dev/null)" = "$_rc_body" ] \
        && [ -L "$_rc_link" ] && [ "$(readlink "$_rc_link")" = "$_rc_plist" ] \
        && launchctl print "gui/$(id -u)/$_rc_label" >/dev/null 2>&1; then
        ok "LaunchAgent $_rc_label"
    elif [ "$INSTALL" = "false" ]; then
        skip "LaunchAgent $_rc_label"
    else
        mkdir -p "$HOME/opt/my-setup/logs" "$HOME/Library/LaunchAgents"
        cp "$SCRIPT_DIR/files/remote_control.sh" "$_rc_script"
        printf '%s\n' "$_rc_body" > "$_rc_plist"
        ln -sfn "$_rc_plist" "$_rc_link"
        launchctl bootout "gui/$(id -u)/$_rc_label" 2>/dev/null || true
        if launchctl bootstrap "gui/$(id -u)" "$_rc_link"; then
            installed "LaunchAgent $_rc_label"
        else
            fail "LaunchAgent $_rc_label: launchctl bootstrap failed"
        fi
    fi
fi
