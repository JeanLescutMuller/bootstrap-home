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
#
# configure_shellrc.sh is NOT in this list - it's a generator script, not
# static content. Its output is concatenated directly into the managed
# block in ~/.zshrc or ~/.bashrc instead (see "shell rc managed block"
# below).
#
# statusline-command.md is NOT in this list either - it's reference
# documentation for statusline-command.sh, not something meant to land
# in ~/.claude/.
DOTFILES=(
    "vimrc:$HOME/.vimrc"
    "tmux.conf:$HOME/.tmux.conf"
    "CLAUDE.md:$HOME/.claude/CLAUDE.md"
    "dev_CLAUDE.md:$HOME/dev/CLAUDE.md"
    "statusline-command.sh:$HOME/.claude/statusline-command.sh"
    "statusline-usage-fetch.sh:$HOME/.claude/statusline-usage-fetch.sh"
    "skills/claude-config-ownership/SKILL.md:$HOME/.claude/skills/claude-config-ownership/SKILL.md"
    "skills/shell-scripting/SKILL.md:$HOME/.claude/skills/shell-scripting/SKILL.md"
    "skills/python-coding/SKILL.md:$HOME/.claude/skills/python-coding/SKILL.md"
)

# Backs up $1 to a single non-timestamped "$1.bak" before it gets
# overwritten, replacing whatever backup was already there. Deliberately
# not timestamped/accumulating: every past deployed state that came from
# a prior bootstrap-home run is already recoverable from this repo's own
# git history (files/ is version-controlled), so the only backup that
# ever carries unique information is the one taken right before the very
# next overwrite - e.g. to recover a target that was hand-edited outside
# of bootstrap-home since the last deploy. Keeping more than one adds
# clutter with no extra recovery value.
_backup_before_overwrite() {
    local target="$1"
    [ -f "$target" ] && cp "$target" "${target}.bak"
}

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
    _backup_before_overwrite "$target"
    cp "$src" "$target"
    installed "$name"

    if [ "$name" = "tmux.conf" ]; then
        tmux info &>/dev/null && tmux source-file "$target" 2>/dev/null && ok "tmux config reloaded"
    fi
}

# Own binaries: real file under ~/opt/bootstrap-home/bin/, symlinked from
# ~/.local/bin/ (per files/CLAUDE.md's rule that ~/.local/bin holds only
# symlinks into ~/opt/<project>/, never real files - same pattern as
# claude-session-manager's csm/status or notify's own binary). Shape
# mirrors DOTFILES: source name in files/, bin name on PATH.
OWN_BINS=(
    "get_host_color.sh:get_host_color"
    "statusline-glances-poll.sh:statusline-glances-poll"
)

_deploy_own_bin() {
    local name="$1" bin_name="$2"
    local src="$SCRIPT_DIR/files/$name"
    local target="$HOME/opt/bootstrap-home/bin/$bin_name"
    local link="$HOME/.local/bin/$bin_name"

    if [ ! -f "$src" ]; then
        fail "$bin_name (not found in files/)"
        return
    fi

    if [ -f "$target" ] && diff -q "$src" "$target" >/dev/null 2>&1 \
        && [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        ok "$bin_name"
        return
    fi

    if [ "$INSTALL" = "false" ]; then
        skip "$bin_name"
        return
    fi

    mkdir -p "$(dirname "$target")" "$(dirname "$link")"
    _backup_before_overwrite "$target"
    cp "$src" "$target"
    chmod +x "$target"
    ln -sf "$target" "$link"
    installed "$bin_name"
}

_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
    else shasum -a 256 | awk '{print $1}'; fi
}

# Idempotently manages a box-delimited, hash-verified block in $1 (target
# file) labeled $2 (e.g. "BOOTSTRAP-HOME"), containing $3 (desired
# content). Removes and reconstructs the block every time it's called -
# never touches anything outside it. Same format as notify's own tmux-hook
# injection (release_v4/notify's deploy_managed_block) - keep both in sync
# if this changes. If the block was hand-edited since it was last written
# (hash mismatch), leaves the file untouched, prints a diff, and fails
# instead of overwriting the edit.
_deploy_managed_block() {
    local target="$1" label="$2" desired="$3"
    local top="# ┌─ ${label} BLOCK ─────────────────────────────────────────────"

    local desired_hash
    desired_hash="$(printf '%s\n' "$desired" | _sha256)"

    local current="" recorded_hash=""
    if [ -f "$target" ] && grep -qF "$top" "$target"; then
        current="$(awk -v top="$top" '
            $0==top { inblock=1; next }
            inblock && /^# └/ { inblock=0; next }
            inblock && /^# [┌│]/ { next }
            inblock { print }
        ' "$target")"
        recorded_hash="$(grep -F "${label} BLOCK END" "$target" | sed -E 's/.*sha256:([0-9a-f]+).*/\1/')"
    fi

    if [ -n "$recorded_hash" ] && [ "$(printf '%s\n' "$current" | _sha256)" != "$recorded_hash" ]; then
        fail "$(basename "$target") ${label} block was hand-edited since the last deploy - not touching it"
        echo "    diff (current vs. what would be deployed):"
        diff <(printf '%s\n' "$current") <(printf '%s\n' "$desired") | sed 's/^/    /'
        return 1
    fi

    if [ "$current" = "$desired" ] && [ -n "$recorded_hash" ]; then
        ok "$(basename "$target") ${label} block"
        return 0
    fi

    if [ "$INSTALL" = "false" ]; then
        skip "$(basename "$target") ${label} block"
        return 0
    fi

    _backup_before_overwrite "$target"

    if [ -f "$target" ] && grep -qF "$top" "$target"; then
        awk -v top="$top" '
            $0==top { inblock=1; next }
            inblock && /^# └/ { inblock=0; next }
            inblock { next }
            { print }
        ' "$target" > "${target}.tmp" && mv "${target}.tmp" "$target"
    fi

    # Trim trailing blank lines left over from a previous deploy, so the
    # blank-line separator below never accumulates across re-installs.
    if [ -f "$target" ]; then
        awk '{ l[NR]=$0 } END { n=NR; while (n>0 && l[n]=="") n--; for (i=1;i<=n;i++) print l[i] }' \
            "$target" > "${target}.tmp" && mv "${target}.tmp" "$target"
    fi

    {
        [ -s "$target" ] && echo ""
        echo "$top"
        echo "# │ DO NOT EDIT - auto-generated by bootstrap-home. Edits inside"
        echo "# │ this block are overwritten on every install. Put your own"
        echo "# │ customizations below this block instead."
        printf '%s\n' "$desired"
        echo "# │ ${label} BLOCK END — sha256:${desired_hash}"
        echo "# └────────────────────────────────────────────────────────────"
    } >> "$target"
    installed "$(basename "$target") ${label} block"
}

step "dotfiles"
for entry in "${DOTFILES[@]}"; do
    _deploy_dotfile "${entry%%:*}" "${entry#*:}"
done

step "own binaries"
for entry in "${OWN_BINS[@]}"; do
    _deploy_own_bin "${entry%%:*}" "${entry#*:}"
done

step "shell rc managed block"
case "$(basename "$SHELL")" in
    zsh)
        _deploy_managed_block "$HOME/.zshrc" "BOOTSTRAP-HOME" \
            "$(bash "$SCRIPT_DIR/files/configure_shellrc.sh" zsh)"
        ;;
    bash)
        _deploy_managed_block "$HOME/.bashrc" "BOOTSTRAP-HOME" \
            "$(bash "$SCRIPT_DIR/files/configure_shellrc.sh" bash)"
        ;;
    *)
        warn "Unrecognized login shell '$SHELL' - skipping shell rc managed block"
        ;;
esac

# --- Modules: real logic (branching, external calls) lives here. ---
MODULES=(dev_layout gitconfig claude_config tools)

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
