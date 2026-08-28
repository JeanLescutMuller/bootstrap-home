#!/bin/bash
# Installs and migrates the shared lazy statusline cache runtime.
step "statusline cache"

RUNTIME="$HOME/opt/bootstrap-home/statusline"
STATE="$RUNTIME/state"
LEGACY="$RUNTIME/legacy"
OLD_CACHE="$HOME/.claude/statusline-caches"
SEPARATOR=$'\034'

if [ "$INSTALL" = "false" ]; then
    if [ -s "$STATE/static/hostname" ] && [ -s "$STATE/static/host-color" ] \
        && [ ! -e "$OLD_CACHE" ] \
        && [ ! -d "$STATE/git/repositories" ] \
        && [ ! -e "$HOME/Library/LaunchAgents/com.bootstrap-home.statusline-glances-poll.plist" ]; then
        ok "shared lazy cache"
    else
        skip "shared lazy cache migration"
    fi
    return
fi

hostname_short="$(hostname -s 2>/dev/null || hostname)"
host_color="$("$HOME/opt/bootstrap-home/bin/get_host_color" \
    "$hostname_short" 2>/dev/null || printf '45')"
current_hostname=""; current_host_color=""
legacy_scheduler=false
[ -f "$STATE/static/hostname" ] && IFS= read -r current_hostname < "$STATE/static/hostname"
[ -f "$STATE/static/host-color" ] && IFS= read -r current_host_color < "$STATE/static/host-color"
if [ "$(uname -s)" = "Darwin" ]; then
    [ -e "$HOME/Library/LaunchAgents/com.bootstrap-home.statusline-glances-poll.plist" ] \
        && legacy_scheduler=true
else
    if [ -e "$HOME/.config/systemd/user/statusline-glances-poll.service" ] \
        || [ -e "$HOME/.config/systemd/user/statusline-glances-poll.timer" ]; then
        legacy_scheduler=true
    fi
fi
if [ "$current_hostname" = "$hostname_short" ] \
    && [ "$current_host_color" = "$host_color" ] \
    && [ ! -e "$OLD_CACHE" ] \
    && [ ! -d "$STATE/git/repositories" ] \
    && [ "$legacy_scheduler" = false ] \
    && [ ! -e "$HOME/.local/bin/statusline-glances-poll" ] \
    && [ ! -e "$HOME/opt/bootstrap-home/bin/statusline-glances-poll" ]; then
    ok "shared lazy cache"
    return
fi

mkdir -p "$STATE/static" "$STATE/system" "$STATE/providers" \
    "$RUNTIME/locks" "$LEGACY"

if [ -d "$STATE/git/repositories" ]; then
    legacy_git="$LEGACY/git-repository-cache-layout"
    [ -e "$legacy_git" ] && legacy_git="${legacy_git}.$$"
    mv "$STATE/git" "$legacy_git"
fi
mkdir -p "$STATE/git/cwd"

printf '%s\n' "$hostname_short" > "$STATE/static/hostname.tmp"
mv "$STATE/static/hostname.tmp" "$STATE/static/hostname"
printf '%s\n' "$host_color" > "$STATE/static/host-color.tmp"
mv "$STATE/static/host-color.tmp" "$STATE/static/host-color"

if [ -d "$OLD_CACHE" ]; then
    if [ -f "$OLD_CACHE/system-metrics.json" ]; then
        jq -jr --arg separator "$SEPARATOR" '
            [(.mem_used_gb | tostring), (.mem_total_gb | tostring), (.mem_pct | tostring)]
            | join($separator), "\n"
        ' "$OLD_CACHE/system-metrics.json" > "$STATE/system/metrics.tmp" 2>/dev/null \
            && mv "$STATE/system/metrics.tmp" "$STATE/system/metrics"
        jq -r '.fetched_at // 0' "$OLD_CACHE/system-metrics.json" \
            > "$STATE/system/metrics.timestamp.tmp" 2>/dev/null \
            && mv "$STATE/system/metrics.timestamp.tmp" "$STATE/system/metrics.timestamp"
    fi

    if [ -f "$OLD_CACHE/claude-utilization.json" ]; then
        jq -jr --arg separator "$SEPARATOR" '
            [
                (.five_hour.pct // "" | tostring),
                (.five_hour.resets_at // "" | tostring),
                (.seven_day.pct // "" | tostring),
                (.seven_day.resets_at // "" | tostring)
            ] | join($separator), "\n"
        ' "$OLD_CACHE/claude-utilization.json" > "$STATE/providers/claude.tmp" 2>/dev/null \
            && mv "$STATE/providers/claude.tmp" "$STATE/providers/claude"
        jq -r '.fetched_at // 0' "$OLD_CACHE/claude-utilization.json" \
            > "$STATE/providers/claude.timestamp.tmp" 2>/dev/null \
            && mv "$STATE/providers/claude.timestamp.tmp" "$STATE/providers/claude.timestamp"
    fi

    if [ ! -e "$LEGACY/claude-statusline-caches" ]; then
        mv "$OLD_CACHE" "$LEGACY/claude-statusline-caches"
    fi
fi

if [ "$(uname -s)" = "Darwin" ]; then
    plist="$HOME/Library/LaunchAgents/com.bootstrap-home.statusline-glances-poll.plist"
    if [ -e "$plist" ] || [ -L "$plist" ]; then
        launchctl unload "$plist" >/dev/null 2>&1 || true
        mv "$plist" "$LEGACY/com.bootstrap-home.statusline-glances-poll.plist"
    fi
else
    unit_dir="$HOME/.config/systemd/user"
    systemctl --user disable --now statusline-glances-poll.timer >/dev/null 2>&1 || true
    for unit in statusline-glances-poll.service statusline-glances-poll.timer; do
        [ -e "$unit_dir/$unit" ] && mv "$unit_dir/$unit" "$LEGACY/$unit"
    done
    systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

poll_link="$HOME/.local/bin/statusline-glances-poll"
poll_bin="$HOME/opt/bootstrap-home/bin/statusline-glances-poll"
if [ -L "$poll_link" ] && [ "$(readlink "$poll_link")" = "$poll_bin" ]; then
    rm "$poll_link"
fi
[ -e "$poll_bin" ] && mv "$poll_bin" "$LEGACY/statusline-glances-poll"

installed "shared lazy cache"
