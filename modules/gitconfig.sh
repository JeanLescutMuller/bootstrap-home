#!/bin/bash
# Ensures git identity, pull.rebase=false, and the right credential helper
# for this OS. On macOS, credential.helper usually already resolves to
# osxkeychain via the system-level gitconfig (Xcode Command Line Tools) -
# in that case this is a no-op check, nothing gets written to ~/.gitconfig.
step "gitconfig"

GIT_NAME="Jean Lescut-Muller"
GIT_EMAIL="jean.lescut@gmail.com"

_check_or_set() {
    local key="$1" want="$2"
    local have
    have="$(git config --get "$key" 2>/dev/null)"

    if [ "$have" = "$want" ]; then
        ok "$key = $want"
    elif [ "$INSTALL" = "false" ]; then
        skip "$key (want '$want', have '${have:-<unset>}')"
    else
        git config --global "$key" "$want"
        installed "$key = $want"
    fi
}

_check_or_set "user.name" "$GIT_NAME"
_check_or_set "user.email" "$GIT_EMAIL"
_check_or_set "pull.rebase" "false"

if [[ "$(uname -s)" == "Darwin" ]]; then
    _check_or_set "credential.helper" "osxkeychain"
else
    _check_or_set "credential.helper" "store"
fi
