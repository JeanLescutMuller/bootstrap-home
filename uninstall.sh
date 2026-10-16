#!/bin/bash
# Removes what modules/agent_links.sh deploys: the skill links
# in ~/.claude/skills and ~/.agents/skills
# (only links that point into ~/opt/bootstrap-home), then the read-only copies
# they point to. Dotfiles, the shell rc block, git config and the tools are left alone.
#
# Usage: bash uninstall.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

OPT_DIR="$HOME/opt/bootstrap-home"

_remove_link() {
    local link="$1" target="$2"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        rm "$link"
        installed "removed $link"
    fi
}

step "agent links"
for dst in "$OPT_DIR"/skills/*/; do
    [ -d "$dst" ] || continue
    for home in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
        _remove_link "$home/$(basename "$dst")" "${dst%/}"
    done
done
for copy in "$OPT_DIR/home_AGENTS.md" "$OPT_DIR/skills"; do
    if [ -e "$copy" ]; then
        chmod -R u+w "$copy" && rm -r "$copy"
        installed "removed $copy"
    fi
done
