#!/bin/bash
# Clones/updates the personal tool repos and deploys them.
# claude-session-manager and notify each ship their own idempotent
# install.sh; statusline doesn't manage its own deployment, so it's a
# plain copy to where Claude Code expects it.
step "tools"

TOOLS=(claude-session-manager notify statusline)

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
            # (release_v4/notify, guarded by the "### claude-notify BEGIN ###"
            # marker) - this is deliberately not part of the tmux.conf dotfile.
            NOTIFY_BIN="$HOME/.claude-templates-dev/components/plugins/notify/notify"
            if command -v tmux >/dev/null 2>&1 && grep -qF "### claude-notify BEGIN ###" "$HOME/.tmux.conf" 2>/dev/null; then
                ok "notify init (tmux hooks)"
            elif [ "$INSTALL" = "false" ]; then
                skip "notify init (tmux hooks)"
            elif [ -x "$NOTIFY_BIN" ]; then
                "$NOTIFY_BIN" init && installed "notify init (tmux hooks)" || fail "notify init (tmux hooks)"
            else
                fail "notify init (tmux hooks) - $NOTIFY_BIN not found, install.sh may have failed"
            fi
            ;;
        statusline)
            target="$HOME/.claude/statusline-command.sh"
            if [ -f "$target" ] && diff -q "$repo_dir/statusline-command.sh" "$target" >/dev/null 2>&1; then
                ok "statusline-command.sh"
            elif [ "$INSTALL" = "false" ]; then
                skip "statusline-command.sh"
            else
                cp "$repo_dir/statusline-command.sh" "$target"
                chmod +x "$target"
                installed "statusline-command.sh"
            fi
            ;;
    esac
done
