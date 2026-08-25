#!/bin/bash
# Fetches a genuinely live rate-limit reading for statusline-command.sh.
#
# Claude Code's own stdin payload (rate_limits.*) is a per-session snapshot
# that only updates when that session sends a prompt - it can sit stale for
# hours otherwise (confirmed live, 2026-08-23). The `/usage` command doesn't
# have this problem because it calls its own endpoint directly: GET
# /api/oauth/usage (confirmed via binary inspection - the internal function
# is literally named fetchUtilization). This script does the same call.
#
# Ported from sirmalloc/ccstatusline's usage-fetch.ts
# (github.com/sirmalloc/ccstatusline, src/utils/usage-fetch.ts), which
# reverse-engineered this same endpoint and already handles the caching/
# locking/token-fingerprinting edge cases properly - this is a minimal bash
# port covering just what statusline-command.sh needs.
#
# Called from statusline-command.sh on every render, but does real work
# only when the file cache is stale AND no other invocation currently
# holds the lock: 180s cache TTL, 30s lock TTL, mkdir-based atomic lock
# (same pattern already used for the background git-fetch elsewhere in
# statusline-command.sh).

CACHE_DIR="${STATUSLINE_CACHE_DIR:-$HOME/.claude/statusline-caches}"
mkdir -p "$CACHE_DIR"
CACHE_FILE="$CACHE_DIR/claude-utilization.json"
LOCK_DIR="/tmp/.claude-statusline-usage-lock"
CACHE_MAX_AGE=180
LOCK_MAX_AGE=30

now=$(date +%s)

# Fast path: fresh cache, nothing to do.
if [ -f "$CACHE_FILE" ]; then
  cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
  if [ -n "$cache_mtime" ] && [ $(( now - cache_mtime )) -lt "$CACHE_MAX_AGE" ]; then
    exit 0
  fi
fi

# Respect an in-progress fetch from another concurrently-rendering session -
# mkdir is atomic, same pattern as the git-fetch lock above in this file.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  lock_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null)
  if [ -n "$lock_mtime" ] && [ $(( now - lock_mtime )) -lt "$LOCK_MAX_AGE" ]; then
    exit 0
  fi
  # Stale lock (a previous attempt crashed without cleaning up) - reclaim it.
  rmdir "$LOCK_DIR" 2>/dev/null
  mkdir "$LOCK_DIR" 2>/dev/null || exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# macOS Keychain, same service name ccstatusline uses (confirmed correct -
# this is literally what Claude Code itself writes to on login).
TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('claudeAiOauth',{}).get('accessToken') or '')" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  exit 0
fi

RESPONSE=$(curl -s -m 5 \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  "https://api.anthropic.com/api/oauth/usage")

if [ -z "$RESPONSE" ]; then
  exit 0
fi

# Convert the API's five_hour/seven_day {utilization, resets_at (ISO)} into
# our simpler {pct, resets_at (epoch)} cache shape.
python3 -c "
import json, sys, time
from datetime import datetime, timezone

try:
    d = json.loads('''$RESPONSE''')
except Exception:
    sys.exit(0)

def bucket(name):
    b = d.get(name)
    if b is None:
        return None
    util = b.get('utilization')
    resets = b.get('resets_at')
    if util is None:
        return None
    epoch = None
    if resets:
        try:
            epoch = int(datetime.fromisoformat(resets.replace('Z', '+00:00')).timestamp())
        except Exception:
            epoch = None
    return {'pct': round(util), 'resets_at': epoch}

out = {'fetched_at': int(time.time())}
fh = bucket('five_hour')
sd = bucket('seven_day')
if fh: out['five_hour'] = fh
if sd: out['seven_day'] = sd

if 'five_hour' in out or 'seven_day' in out:
    with open('$CACHE_FILE', 'w') as f:
        json.dump(out, f)
"
