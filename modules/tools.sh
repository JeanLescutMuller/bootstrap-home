#!/bin/bash
# Deploys the personal tool repos - each ships its own idempotent
# install.sh.
#
# Every machine keeps the clone in ~/dev/<name>: each install.sh symlinks the
# repo's skills into ~/.claude/skills and ~/.agents/skills, so the clone must
# stay. Off the MacBook it is pull-only: code is never edited there.
step "tools"

TOOLS=(agent-session-manager agent-notify agent-statusline agent-usage-tracker)

for name in "${TOOLS[@]}"; do
    if [ "$INSTALL" = "false" ]; then
        skip "$name install.sh"
        continue
    fi

    repo_dir="$HOME/dev/$name"
    url="https://github.com/JeanLescutMuller/$name.git"

    if [ -d "$repo_dir" ]; then
        ok "$name (using existing ~/dev checkout)"
    elif git clone -q "$url" "$repo_dir"; then
        installed "$name (cloned into ~/dev)"
    else
        fail "$name (clone failed)"
        continue
    fi

    if bash "$repo_dir/install.sh" >/dev/null 2>&1; then
        installed "$name install.sh"
    else
        fail "$name install.sh"
    fi

    if [ "$name" = "agent-notify" ]; then
        # notify owns its own tmux-hooks injection via `notify init`
        # (release_v4/notify, guarded by the "# ┌─ CLAUDE-NOTIFY BLOCK ─"
        # marker) - this is deliberately not part of the tmux.conf dotfile.
        NOTIFY_BIN="$HOME/opt/agent-notify/app/notify"
        if command -v tmux >/dev/null 2>&1 && grep -qF "# ┌─ CLAUDE-NOTIFY BLOCK" "$HOME/.tmux.conf" 2>/dev/null; then
            ok "notify init (tmux hooks)"
        elif [ -x "$NOTIFY_BIN" ]; then
            "$NOTIFY_BIN" init && installed "notify init (tmux hooks)" || fail "notify init (tmux hooks)"
        else
            fail "notify init (tmux hooks) - $NOTIFY_BIN not found, install.sh may have failed"
        fi
    fi

done
