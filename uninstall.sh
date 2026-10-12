#!/bin/bash
# Removes what bootstrap.sh links into the agents' homes: the instruction
# symlinks (~/.claude/CLAUDE.md, ~/.codex/AGENTS.md) and one symlink per skill
# in ~/.claude/skills and ~/.agents/skills - only links that point into this
# clone. Dotfiles, the shell rc block, git config and the tools are left alone.
#
# Usage: bash uninstall.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

_remove_link() {
    local link="$1" src="$2"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then
        rm "$link"
        installed "removed $link"
    fi
}

step "agent links"
_remove_link "$HOME/.claude/CLAUDE.md" "$SCRIPT_DIR/files/home_AGENTS.md"
_remove_link "$HOME/.codex/AGENTS.md" "$SCRIPT_DIR/files/home_AGENTS.md"
for src in "$SCRIPT_DIR"/skills/*/; do
    for home in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
        _remove_link "$home/$(basename "$src")" "${src%/}"
    done
done
