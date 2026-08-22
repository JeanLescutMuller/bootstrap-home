#!/bin/bash
# Clones/updates the personal tool repos and deploys them - each ships
# its own idempotent install.sh. statusline used to be here too, but it
# was never really an independent tool (no install.sh of its own, no
# CLI, no lifecycle) - it's now a plain bootstrap-home dotfile instead
# (files/statusline-command.sh), same as vimrc/tmux.conf.
step "tools"

TOOLS=(claude-session-manager notify)

for name in "${TOOLS[@]}"; do
    repo_dir="$HOME/dev/$name"
    url="https://github.com/JeanLescutMuller/$name.git"

    if [ ! -d "$repo_dir" ]; then
        if [ "$INSTALL" = "false" ]; then
            skip "$name (not cloned)"
            continue
        fi
        git clone -q "$url" "$repo_dir" && installed "$name (cloned)"
    else
        ok "$name (cloned)"
    fi

    case "$name" in
        claude-session-manager)
            if [ "$INSTALL" = "false" ]; then
                skip "$name install.sh"
            elif bash "$repo_dir/install.sh" >/dev/null 2>&1; then
                installed "$name install.sh"
            else
                fail "$name install.sh"
            fi
            ;;
        notify)
            if [ "$INSTALL" = "false" ]; then
                skip "$name install.sh"
            elif bash "$repo_dir/install.sh" >/dev/null 2>&1; then
                installed "$name install.sh"
            else
                fail "$name install.sh"
            fi

            # notify owns its own tmux-hooks injection via `notify init`
            # (release_v4/notify, guarded by the "# ┌─ CLAUDE-NOTIFY BLOCK ─"
            # marker) - this is deliberately not part of the tmux.conf dotfile.
            NOTIFY_BIN="$HOME/.claude-templates-dev/components/plugins/notify/notify"
            if command -v tmux >/dev/null 2>&1 && grep -qF "# ┌─ CLAUDE-NOTIFY BLOCK" "$HOME/.tmux.conf" 2>/dev/null; then
                ok "notify init (tmux hooks)"
            elif [ "$INSTALL" = "false" ]; then
                skip "notify init (tmux hooks)"
            elif [ -x "$NOTIFY_BIN" ]; then
                "$NOTIFY_BIN" init && installed "notify init (tmux hooks)" || fail "notify init (tmux hooks)"
            else
                fail "notify init (tmux hooks) - $NOTIFY_BIN not found, install.sh may have failed"
            fi
            ;;
    esac
done
