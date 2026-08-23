#!/bin/bash
# configure_shellrc.sh - generates the bootstrap-home managed block content
# for one shell. Organized by topic (PATH, ls/ll, history, prompt), not by
# shell - branches internally only where bash/zsh syntax genuinely differs.
# Usage: configure_shellrc.sh zsh|bash   (output -> the managed block body)
set -euo pipefail
TARGET_SHELL="$1"   # "zsh" or "bash"

# --- Greeting ---
echo "echo 'Loading ~/.${TARGET_SHELL}rc ...'"

# --- PATH ---
cat << 'EOF'
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
EOF

# --- ls / ll: colorized, ll always shows hidden files with human-readable
# sizes, regardless of which of these three cases applies. Same on every
# shell, so no branching here. ---
cat << 'EOF'

if command -v gls >/dev/null 2>&1 && command -v gdircolors >/dev/null 2>&1; then
    # GNU coreutils via Homebrew (macOS)
    if [[ -r "$HOME/.dircolors" ]]; then
        eval "$(gdircolors -b "$HOME/.dircolors")"
    else
        eval "$(gdircolors -b)"
    fi
    alias ls='gls --color=auto'
    alias ll='gls --color=auto -lAh'
elif command -v dircolors >/dev/null 2>&1; then
    # Native GNU coreutils (Linux)
    if [[ -r "$HOME/.dircolors" ]]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto'
    alias ll='ls --color=auto -lAh'
else
    # BSD ls fallback (macOS without Homebrew coreutils)
    export CLICOLOR=1
    export LSCOLORS='Exfxcxdxbxegedabagacad'
    alias ls='ls -G'
    alias ll='ls -lAhG'
fi
EOF

# --- History: large, deduplicated, timestamped everywhere. Syntax differs
# per shell (setopt vs. HISTCONTROL/shopt), so this is the first spot that
# actually branches. ---
if [ "$TARGET_SHELL" = "zsh" ]; then
    cat << 'EOF'

export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000
setopt EXTENDED_HISTORY       # timestamps + duration
setopt INC_APPEND_HISTORY     # write immediately
setopt SHARE_HISTORY          # across terminals
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
EOF
elif [ "$TARGET_SHELL" = "bash" ]; then
    cat << 'EOF'

export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=100000
export HISTFILESIZE=100000
export HISTTIMEFORMAT="%Y-%m-%d %T "
shopt -s histappend
# bash has no built-in cross-terminal live sharing like zsh's SHARE_HISTORY,
# so PROMPT_COMMAND writes after every command instead.
export PROMPT_COMMAND="history -a; ${PROMPT_COMMAND:-}"
EOF
fi

# --- Prompt: italic user (red if root, else cyan - whoami-based, no
# marker file needed), hashed host color, bold yellow workdir. Same color
# scheme on both shells, different escape syntax.
#
# Host color: same SHA-256 -> mod 14 -> HOST_PALETTE logic as the statusline
# script's host_color() (files/statusline-command.sh) - same 14 xterm-256
# codes, same order, so a given machine's prompt and statusline land on the
# identical color. Computed once at rc-load time (hostname doesn't change
# mid-session), not per-prompt like the statusline (which re-execs as a
# fresh process on every render). A case statement, not a bash/zsh array,
# because zsh arrays are 1-indexed by default and bash's are 0-indexed -
# a case on 0-13 sidesteps that entirely and is identical text in both
# branches below. ---
_BH_HOST_COLOR_CASE='case "$1" in
    0) echo 25 ;; 1) echo 27 ;; 2) echo 33 ;; 3) echo 39 ;; 4) echo 45 ;;
    5) echo 51 ;; 6) echo 50 ;; 7) echo 44 ;; 8) echo 57 ;; 9) echo 63 ;;
    10) echo 99 ;; 11) echo 129 ;; 12) echo 135 ;; 13) echo 141 ;;
esac'

_BH_HOST_COLOR_SETUP=$(cat << EOF
_bh_host_palette_code() {
    $_BH_HOST_COLOR_CASE
}
_bh_hostname=\$(hostname -s 2>/dev/null || hostname)
if command -v sha256sum >/dev/null 2>&1; then
    _bh_host_hash=\$(printf '%s' "\$_bh_hostname" | sha256sum | cut -c1-8)
else
    _bh_host_hash=\$(printf '%s' "\$_bh_hostname" | shasum -a 256 | cut -c1-8)
fi
_bh_host_dec=\$((16#\$_bh_host_hash))
_bh_host_color=\$(_bh_host_palette_code \$(( _bh_host_dec % 14 )))
EOF
)

if [ "$TARGET_SHELL" = "zsh" ]; then
    echo
    echo "$_BH_HOST_COLOR_SETUP"
    cat << 'EOF'
if [ "$(whoami)" = "root" ]; then
    _bh_user_color="red"
else
    _bh_user_color="cyan"
fi
autoload -U colors && colors
PS1="%{$fg[$_bh_user_color]%}%n%{$reset_color%}@%F{$_bh_host_color}%m %{$fg[yellow]%}%~ %{$reset_color%}%% "
unset _bh_user_color _bh_hostname _bh_host_hash _bh_host_dec _bh_host_color
unfunction _bh_host_palette_code
EOF
elif [ "$TARGET_SHELL" = "bash" ]; then
    echo
    echo "$_BH_HOST_COLOR_SETUP"
    cat << 'EOF'
if [ "$(whoami)" = "root" ]; then
    _bh_user_color="31"
else
    _bh_user_color="36"
fi
export PS1="\[\033[3;${_bh_user_color}m\]\u\[\033[m\]@\[\033[38;5;${_bh_host_color}m\]\h:\[\033[1;33m\]\w\[\033[m\]\$ "
unset _bh_user_color _bh_hostname _bh_host_hash _bh_host_dec _bh_host_color
unset -f _bh_host_palette_code
EOF
fi
