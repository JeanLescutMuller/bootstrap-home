#!/bin/bash
# Prints live Claude quotas as: 5h_pct FS 5h_reset_epoch FS 7d_pct FS 7d_reset_epoch.
# Cache freshness, locking, timeouts, and atomic writes are owned by
# statusline-cache.sh; this file performs one refresh attempt only.
set -uo pipefail

separator=$'\034'
token=""

if [ "$(uname -s)" = "Darwin" ]; then
    credentials="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)" || exit 1
else
    credentials_file="$HOME/.claude/.credentials.json"
    [ -f "$credentials_file" ] || exit 1
    credentials="$(<"$credentials_file")"
fi

token="$(printf '%s' "$credentials" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)"
[ -n "$token" ] || exit 1

curl --fail --silent --show-error --max-time 4 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" \
    | jq -jr --arg separator "$separator" '
        def epoch:
            if . == null then ""
            else fromdateiso8601 | tostring
            end;
        [
            ((.five_hour.utilization // 0) | round | tostring),
            (.five_hour.resets_at | epoch),
            ((.seven_day.utilization // 0) | round | tostring),
            (.seven_day.resets_at | epoch)
        ] | join($separator), "\n"
    '
