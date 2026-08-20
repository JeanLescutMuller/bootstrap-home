#!/bin/bash
# Personal machine bootstrap - dotfiles + dev tools, user-space only.
# Safe to run on a machine you don't own: no root/sudo assumed anywhere.
#
# Usage:
#   bash bootstrap.sh                # check only (default)
#   INSTALL=true bash bootstrap.sh   # check + install dotfiles and all modules
#   INSTALL=true bash bootstrap.sh gitconfig   # dotfiles (always) + one module
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

export INSTALL="${INSTALL:-false}"
export SCRIPT_DIR

if [ "$INSTALL" = "true" ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} bootstrap-home (install mode)${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} bootstrap-home (status check)${NC}"
    echo -e "${GREEN}========================================${NC}"
fi

# --- Plain file-copy dotfiles: (source in files/, target path). ---
# Everything here is "copy if different, back up the old one" - no other
# logic. Real logic (directories, git config, tool installs) lives in
# modules/ instead - see the bottom of this file.
DOTFILES=(
    "vimrc:$HOME/.vimrc"
    "tmux.conf:$HOME/.tmux.conf"
    "CLAUDE.md:$HOME/.claude/CLAUDE.md"
    "shellrc_common:$HOME/.shellrc_common"
)

# Only one of these applies, matching the machine's login shell.
case "$(basename "$SHELL")" in
    zsh)  DOTFILES+=("zshrc_thin:$HOME/.zshrc_bootstrap") ;;
    bash) DOTFILES+=("bashrc_thin:$HOME/.bashrc_bootstrap") ;;
    *)    warn "Unrecognized login shell '$SHELL' - skipping prompt/history dotfile" ;;
esac

_deploy_dotfile() {
    local name="$1" target="$2"
    local src="$SCRIPT_DIR/files/$name"

    if [ ! -f "$src" ]; then
        fail "$name (not found in files/)"
        return
    fi

    if [ -f "$target" ] && diff -q "$src" "$target" >/dev/null 2>&1; then
        ok "$name"
        return
    fi

    if [ "$INSTALL" = "false" ]; then
        skip "$name"
        return
    fi

    mkdir -p "$(dirname "$target")"
    [ -f "$target" ] && cp "$target" "${target}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$src" "$target"
    installed "$name"

    if [ "$name" = "tmux.conf" ]; then
        tmux info &>/dev/null && tmux source-file "$target" 2>/dev/null && ok "tmux config reloaded"
    fi
}

_ensure_source_line() {
    # Idempotently ensures $2 sources $1, appending only if missing.
    # Never rewrites or removes existing content in $2.
    local src_file="$1" rc_file="$2"
    local line="[ -f \"$src_file\" ] && source \"$src_file\""

    if [ -f "$rc_file" ] && grep -qF "$src_file" "$rc_file" 2>/dev/null; then
        ok "$(basename "$rc_file") sources $(basename "$src_file")"
        return
    fi

    if [ "$INSTALL" = "false" ]; then
        skip "$(basename "$rc_file") does not yet source $(basename "$src_file")"
        return
    fi

    [ -f "$rc_file" ] && cp "$rc_file" "${rc_file}.bak.$(date +%Y%m%d_%H%M%S)"
    {
        echo ""
        echo "# --- bootstrap-home ---"
        echo "$line"
    } >> "$rc_file"
    installed "appended source line to $(basename "$rc_file")"
}

step "dotfiles"
for entry in "${DOTFILES[@]}"; do
    _deploy_dotfile "${entry%%:*}" "${entry#*:}"
done

step "shell rc source lines"
case "$(basename "$SHELL")" in
    zsh)
        _ensure_source_line "$HOME/.shellrc_common" "$HOME/.zshrc"
        _ensure_source_line "$HOME/.zshrc_bootstrap" "$HOME/.zshrc"
        ;;
    bash)
        _ensure_source_line "$HOME/.shellrc_common" "$HOME/.bashrc"
        _ensure_source_line "$HOME/.bashrc_bootstrap" "$HOME/.bashrc"
        ;;
esac

# --- Modules: real logic (branching, external calls) lives here. ---
MODULES=(dev_layout gitconfig tools)

TARGET="${1:-}"
if [ -n "$TARGET" ]; then
    if [ -f "$SCRIPT_DIR/modules/${TARGET}.sh" ]; then
        source "$SCRIPT_DIR/modules/${TARGET}.sh"
    else
        fail "No module named '$TARGET' (dotfiles above always run; valid modules: ${MODULES[*]})"
        exit 1
    fi
else
    for mod in "${MODULES[@]}"; do
        source "$SCRIPT_DIR/modules/$mod.sh"
    done
fi

echo ""
