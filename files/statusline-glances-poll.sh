#!/bin/bash
# Samples CPU/memory via glances and writes one JSON snapshot to the
# shared statusline cache. Run periodically by an OS-native scheduler
# (see modules/statusline_metrics.sh - a launchd timer on macOS, a
# systemd --user timer on Linux), NOT invoked per statusline render -
# statusline-command.sh just reads whatever this last wrote, a zero-fork
# file read instead of a vm_stat/top call on every one of its own renders.
#
# Deliberately decoupled from session count: with 30-50 concurrent Claude
# Code sessions common, one sample on a fixed schedule costs the same
# regardless of how many sessions are open, instead of the old design
# where every session's every render paid its own memory-read cost.
#
# glances itself isn't cheap per invocation (~0.4s CPU, ~2.5s wall,
# measured 2026-08-26 - full Python + psutil startup each time) but at
# one sample per 30s that's under 2% of a single core sustained, and
# that cost no longer scales with session count at all.
set -euo pipefail

# Schedulers (launchd, systemd, cron) never reliably inherit an
# interactive shell's PATH - confirmed live, 2026-08-26, twice: launchd's
# minimal PATH doesn't include Homebrew's /opt/homebrew/bin (Apple
# Silicon), and separately, systemd --user's own default PATH doesn't
# include ~/.local/bin (where `pip install --user` puts the glances
# binary on Linux) - both silently failed with "command not found"
# (exit 127) the first time their real scheduler fired this rather than
# a shell with the full PATH already set up.
PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CACHE_DIR="$HOME/.claude/statusline-caches"
mkdir -p "$CACHE_DIR"
CACHE_FILE="$CACHE_DIR/system-metrics.json"

glances --stdout-json cpu,mem 2>/dev/null | python3 -c "
import json
import os
import sys
import time

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

mem = data.get('mem', {})
cpu = data.get('cpu', {})

out = {
    'fetched_at': int(time.time()),
    'mem_used_gb': round(mem.get('used', 0) / 1024**3, 1),
    'mem_total_gb': round(mem.get('total', 0) / 1024**3, 1),
    'mem_pct': round(mem.get('percent', 0)),
    'cpu_pct': round(cpu.get('total', 0)),
}

cache_file = '$CACHE_FILE'
tmp = cache_file + '.tmp'
with open(tmp, 'w') as f:
    json.dump(out, f)
os.replace(tmp, cache_file)
"
