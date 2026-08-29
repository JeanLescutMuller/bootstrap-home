#!/bin/bash
# Deploys the personal tool repos - each ships its own idempotent
# install.sh.
#
# ~/dev/<name> only exists persistently on the MacBook (the one machine
# development happens on). On any other machine, install.sh is run from
# a scratch clone that's deleted right after - ~/dev stays empty there
# by design, since these tools deploy to ~/opt/<name>/, not ~/dev/<name>/.
step "tools"

TOOLS=(claude-session-manager notify agent-statusline)

for name in "${TOOLS[@]}"; do
    if [ "$INSTALL" = "false" ]; then
        skip "$name install.sh"
        continue
    fi

    persistent_dir="$HOME/dev/$name"
    url="https://github.com/JeanLescutMuller/$name.git"
    scratch_dir=""

    if [ -d "$persistent_dir" ]; then
        repo_dir="$persistent_dir"
        ok "$name (using existing ~/dev checkout)"
    else
        scratch_dir="$(mktemp -d)"
        repo_dir="$scratch_dir"
        if ! git clone -q "$url" "$repo_dir"; then
            fail "$name (clone failed)"
            rm -rf "$scratch_dir"
            continue
        fi
        installed "$name (installed from a scratch clone, not kept in ~/dev)"
    fi

    if bash "$repo_dir/install.sh" >/dev/null 2>&1; then
        installed "$name install.sh"
    else
        fail "$name install.sh"
    fi

    if [ "$name" = "notify" ]; then
        # notify owns its own tmux-hooks injection via `notify init`
        # (release_v4/notify, guarded by the "# ┌─ CLAUDE-NOTIFY BLOCK ─"
        # marker) - this is deliberately not part of the tmux.conf dotfile.
        NOTIFY_BIN="$HOME/.claude-templates-dev/components/plugins/notify/notify"
        if command -v tmux >/dev/null 2>&1 && grep -qF "# ┌─ CLAUDE-NOTIFY BLOCK" "$HOME/.tmux.conf" 2>/dev/null; then
            ok "notify init (tmux hooks)"
        elif [ -x "$NOTIFY_BIN" ]; then
            "$NOTIFY_BIN" init && installed "notify init (tmux hooks)" || fail "notify init (tmux hooks)"
        else
            fail "notify init (tmux hooks) - $NOTIFY_BIN not found, install.sh may have failed"
        fi
    fi

    [ -n "$scratch_dir" ] && rm -rf "$scratch_dir"
done
