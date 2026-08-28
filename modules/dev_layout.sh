#!/bin/bash
# Ensures ~/dev, ~/opt, ~/.local/bin exist.
# ~/opt here always means the user-level dir - see files/home_AGENTS.md for the
# distinction from the root-owned system /opt on Linux.
step "directory layout"

DIRS=("$HOME/dev" "$HOME/opt" "$HOME/.local/bin")

for d in "${DIRS[@]}"; do
    if [ -d "$d" ]; then
        ok "$d"
    elif [ "$INSTALL" = "false" ]; then
        skip "$d"
    else
        mkdir -p "$d"
        installed "$d"
    fi
done
