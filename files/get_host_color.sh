#!/bin/bash
# Shared host->color mapping for this machine's shell prompt
# (files/configure_shellrc.sh) and Claude Code statusline
# (files/statusline-command.sh) - one algorithm, deployed once to
# ~/.local/bin (see bootstrap.sh's "own binaries" step), so the two never
# carry their own copies that can drift out of sync.
#
# SHA-256, not cksum: cksum is a CRC, fine for error-detection but
# reducing it mod a small bucket count clusters badly (verified: "mac" and
# "H-Frank-1" landed on the exact same bucket with cksum %6). 14 shades
# keeps collisions rare across a handful of real machines - kept entirely
# in the blue/purple/cyan family, deliberately out of the green/yellow/red
# severity language the statusline uses elsewhere, so it never reads as a
# status signal.
#
# Prints the bare xterm-256 color number (e.g. "129") to stdout - callers
# wrap it in their own escape syntax (bash \033[38;5;Nm, zsh %F{N}, ...)
# rather than this script picking one format for everyone. This is also
# the exact contract of the $HOST_COLOR env var the shell prompt exports.
set -euo pipefail

HOST_PALETTE=(25 27 33 39 45 51 50 44 57 63 99 129 135 141)

host="${1:-$(hostname -s 2>/dev/null || hostname)}"

if command -v sha256sum >/dev/null 2>&1; then
    hex=$(printf '%s' "$host" | sha256sum | cut -c1-8)
else
    hex=$(printf '%s' "$host" | shasum -a 256 | cut -c1-8)
fi

dec=$((16#$hex))
echo "${HOST_PALETTE[$(( dec % ${#HOST_PALETTE[@]} ))]}"
