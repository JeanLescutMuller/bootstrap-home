#!/bin/bash
# Remote Control service (macOS only): a LaunchAgent that keeps
# `claude remote-control` running, so a Claude session on this Mac can be
# started from the phone at any time. The Mac must be awake.
#
#   ~/opt/my-setup/remote_control.sh              - the script launchd runs (from files/)
#   ~/opt/my-setup/com.jeanlescut.my-setup.plist  - the real plist
#   ~/Library/LaunchAgents/com.jeanlescut.my-setup.plist -> the real plist
#   ~/opt/my-setup/logs/remote-control.log        - start, exit, errors
#
# Restarted only when the script or plist changed: a restart ends every
# session open from the phone (including the one running this, if any).

step "remote control service"

if [ "$(uname)" != Darwin ]; then
    ok "not macOS - skipped"
else
    _rc_label="com.jeanlescut.my-setup"
    _rc_opt="$HOME/opt/my-setup"
    _rc_script="$_rc_opt/remote_control.sh"
    _rc_plist="$_rc_opt/$_rc_label.plist"
    _rc_link="$HOME/Library/LaunchAgents/$_rc_label.plist"
    _rc_plist_body="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
  <key>Label</key><string>$_rc_label</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$_rc_script</string></array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>60</integer>
</dict></plist>"

    if diff -q "$SCRIPT_DIR/files/remote_control.sh" "$_rc_script" >/dev/null 2>&1 \
        && [ "$(cat "$_rc_plist" 2>/dev/null)" = "$_rc_plist_body" ] \
        && [ -L "$_rc_link" ] && [ "$(readlink "$_rc_link")" = "$_rc_plist" ] \
        && launchctl print "gui/$(id -u)/$_rc_label" >/dev/null 2>&1; then
        ok "LaunchAgent $_rc_label (claude remote-control)"
    elif [ "$INSTALL" = "false" ]; then
        skip "LaunchAgent $_rc_label (claude remote-control)"
    else
        mkdir -p "$_rc_opt/logs" "$HOME/Library/LaunchAgents"
        cp "$SCRIPT_DIR/files/remote_control.sh" "$_rc_script"
        printf '%s\n' "$_rc_plist_body" > "$_rc_plist"
        ln -sfn "$_rc_plist" "$_rc_link"
        launchctl bootout "gui/$(id -u)/$_rc_label" 2>/dev/null || true
        if launchctl bootstrap "gui/$(id -u)" "$_rc_link"; then
            installed "LaunchAgent $_rc_label (claude remote-control)"
        else
            fail "LaunchAgent $_rc_label: launchctl bootstrap failed"
        fi
    fi
fi
