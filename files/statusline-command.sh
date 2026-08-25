#!/bin/bash
# Custom Claude Code status line.
# Reads the hook JSON payload from stdin (see Claude Code docs for the schema);
# fields used here were confirmed by capturing a live payload on 2026-08-18.

input=$(cat)

# All statusline cache files live under one directory instead of scattered
# loose in ~/.claude/ - claude-utilization.json (5h/7d rate limits, shared
# machine-wide), static.json (machine-invariant data - currently just host
# color), git/<hash(cwd)>.json (per-folder git status, one entry per
# distinct repo path). Locks stay in /tmp (existing precedent, and a lock
# surviving reboot has no value anyway).
CACHE_DIR="$HOME/.claude/statusline-caches"
mkdir -p "$CACHE_DIR/git"

RESET='\033[0m'

# --- lines 1-2: grayscale, brightness = importance ---
GRAY_1='\033[97m'       # bright white  - model+effort (most important)
GRAY_2='\033[37m'       # white         - cwd
GRAY_3='\033[38;5;250m' # light gray    - git branch/diff
GRAY_4='\033[38;5;240m' # dark gray     - entire line 2 (uuid, rotating info)

# --- line 3: criticality colors (green/yellow/red by severity) ---
SEV_GREEN='\033[32m'; SEV_YELLOW='\033[33m'; SEV_RED='\033[31m'
BAR_EMPTY='\033[38;5;238m' # dim track for the unfilled part of a bar

# --- line 1: host identity, hashed color (deliberately not hardcoded) ---
# Comes from the shared get_host_color binary (files/get_host_color.sh,
# deployed to ~/.local/bin) rather than this script carrying its own copy
# of the SHA-256 -> mod 14 -> HOST_PALETTE algorithm - one source of truth
# shared with the shell prompt (files/configure_shellrc.sh). $HOST_COLOR
# is inherited for free in the common case: Claude Code invokes
# statusLine.command via `sh -c "..."`, so this script always runs as a
# descendant of the real login shell (confirmed live, 2026-08-22: the
# ancestor chain is statusline's bash -> throwaway sh -> claude -> login
# shell -> tmux server), which already exported it. Only falls back to
# invoking the binary directly when it isn't set - e.g. Claude Code
# launched outside a shell that ever sourced this repo's rc block.

# --- line 1: git status colors, one per case, distinct from severity ---
# Merge conflicts reuse SEV_RED on purpose (see below) - everything else
# stays out of the green/yellow/red family entirely.
GIT_CYAN='\033[38;5;51m'    # untracked files/folders - informational
GIT_BLUE='\033[38;5;39m'    # staged, not committed - deliberately queued
GIT_PURPLE='\033[38;5;141m' # ahead/behind remote - local vs. shared history,
                            # same color both directions, arrow glyph alone
                            # distinguishes ⇡ ahead from ⇣ behind
# Unstaged tracked changes (!) intentionally get no color of their own -
# stays the same gray as the branch name, since it's the most routine of
# the six states and shouldn't compete for attention.
#
# Conflicts (✖) reuse $SEV_RED, not a new color: a conflict is genuinely
# blocking/needs-action, closer in spirit to line 3's "critical" than to
# a routine file count - reusing red reinforces its one existing meaning
# in this script rather than diluting it with an unrelated second use.

sev_color() {
  local pct=$1
  if [ "$pct" -ge 90 ]; then echo "$SEV_RED"
  elif [ "$pct" -ge 70 ]; then echo "$SEV_YELLOW"
  else echo "$SEV_GREEN"; fi
}

bar() {
  # bar <pct 0-100> <width> <color> -> colored bar, track stays dim
  local pct=$1 width=$2 color=$3
  local filled=$(( pct * width / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width
  local empty=$(( width - filled ))
  printf -v fill "%${filled}s"; printf -v pad "%${empty}s"
  printf '%b%s%b%s%b' "$color" "${fill// /█}" "$BAR_EMPTY" "${pad// /░}" "$RESET"
}

# --- portable epoch -> formatted-date (macOS `date -r`, Linux `date -d @`) ---
# LC_TIME=C: found live that %A respects the machine's locale (this one is
# fr_CH, so "Saturday" rendered as "samedi") - forced to C so weekday names
# are always English regardless of machine locale. Same precedent as the
# LC_ALL=C already forced in the memory-segment awk calls below, for the
# same reason (locale-dependent formatting surprises).
fmt_epoch() {
  local epoch="$1" fmt="$2"
  if [ "$(uname -s)" = "Darwin" ]; then
    LC_TIME=C date -r "$epoch" "+$fmt" 2>/dev/null
  else
    LC_TIME=C date -d "@$epoch" "+$fmt" 2>/dev/null
  fi
}

# 1st/2nd/3rd/4th... no `date` format specifier does this on either platform.
ordinal_suffix() {
  case "$1" in
    1|21|31) echo "st" ;;
    2|22) echo "nd" ;;
    3|23) echo "rd" ;;
    *) echo "th" ;;
  esac
}

# --- parse payload ---
MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
CWD=$(echo "$input" | jq -r '.cwd')
SESSION_ID=$(echo "$input" | jq -r '.session_id')

CTX_PCT=$(echo "$input" | jq -r '(.context_window.used_percentage // 0) | round')

# Claude Code's own stdin snapshot only updates when this session sends a
# prompt - can go stale for hours otherwise (confirmed live, 2026-08-23).
# Used as the starting value, then overridden below by a genuinely live
# reading when one is available.
RL_PCT=$(echo "$input" | jq -r '(.rate_limits.five_hour.used_percentage // 0) | round')
RL_RESETS=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

WK_PCT=$(echo "$input" | jq -r '(.rate_limits.seven_day.used_percentage // 0) | round')
WK_RESETS=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Live rate-limit reading: same GET /api/oauth/usage endpoint the `/usage`
# command itself uses (confirmed via binary inspection, 2026-08-23), fetched
# and cached by statusline-usage-fetch.sh (self-throttled: ~180s cache TTL,
# 30s cross-session lock, so calling it every render is cheap - a no-op
# fast-path except roughly once per 180s). Overrides the stdin snapshot
# above whenever a fresh-enough (<10min old) reading exists; falls back to
# the stdin snapshot otherwise (no token, offline, endpoint down, ...).
STATUSLINE_CACHE_DIR="$CACHE_DIR" bash "$HOME/.claude/statusline-usage-fetch.sh" >/dev/null 2>&1
LIVE_CACHE="$CACHE_DIR/claude-utilization.json"
if [ -f "$LIVE_CACHE" ] && [ "$(( $(date +%s) - $(jq -r '.fetched_at // 0' "$LIVE_CACHE" 2>/dev/null) ))" -lt 600 ]; then
  if [ "$(jq -r 'has("five_hour")' "$LIVE_CACHE" 2>/dev/null)" = "true" ]; then
    RL_PCT=$(jq -r '.five_hour.pct' "$LIVE_CACHE")
    RL_RESETS=$(jq -r '.five_hour.resets_at' "$LIVE_CACHE")
  fi
  if [ "$(jq -r 'has("seven_day")' "$LIVE_CACHE" 2>/dev/null)" = "true" ]; then
    WK_PCT=$(jq -r '.seven_day.pct' "$LIVE_CACHE")
    WK_RESETS=$(jq -r '.seven_day.resets_at' "$LIVE_CACHE")
  fi
fi

# --- line 1: model+effort | cwd | git (only if inside a repo) ---
MODEL_STR="${MODEL}"
[ -n "$EFFORT" ] && MODEL_STR="${MODEL} (${EFFORT})"

# Per-folder cache (not just per-session): several concurrent sessions
# often share the same cwd, and would otherwise each independently re-run
# every git command below on every render. One computation per folder per
# GIT_CACHE_MAX_AGE window, shared by however many sessions are open
# there - same mkdir-lock pattern as everything else here. Caches the
# fully-rendered segment string, not the individual fields, so a cache
# hit is a single jq read with no rebuild logic needed.
GIT_CACHE_KEY=$(printf '%s' "$CWD" | cksum | cut -d' ' -f1)
GIT_CACHE_FILE="$CACHE_DIR/git/$GIT_CACHE_KEY.json"
GIT_CACHE_LOCK="/tmp/.claude-statusline-gitstatus-$GIT_CACHE_KEY"
GIT_CACHE_MAX_AGE=8

GIT_SEG=""
GOT_GIT_CACHE=false
if [ -f "$GIT_CACHE_FILE" ]; then
  GIT_CACHE_AGE=$(( $(date +%s) - $(jq -r '.fetched_at // 0' "$GIT_CACHE_FILE" 2>/dev/null) ))
  if [ "$GIT_CACHE_AGE" -lt "$GIT_CACHE_MAX_AGE" ]; then
    GIT_SEG=$(jq -r '.git_seg' "$GIT_CACHE_FILE" 2>/dev/null)
    GOT_GIT_CACHE=true
  fi
fi

if [ "$GOT_GIT_CACHE" = true ]; then
  : # GIT_SEG already set from cache above
elif mkdir "$GIT_CACHE_LOCK" 2>/dev/null; then
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && BRANCH=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)

  # Background `git fetch` roughly every 30s, so ahead/behind stays fresh
  # without a manual fetch. `(seconds % 30) < 10` is a 10s-wide window every
  # 30s - lines up with the ~10s refresh interval without needing state
  # persisted between invocations (each run is a fresh process). `10#`
  # prefix: date +%S zero-pads ("08","09"), and bash `$(( ))` reads a
  # leading zero as octal, where 8/9 aren't valid digits - would crash
  # without it. Backgrounded + disowned so a slow/offline fetch never
  # blocks the render; mkdir-based lock (atomic, no flock dependency) so a
  # slow fetch can't stack up a second one before the first finishes.
  # Failures are silent on purpose - nothing useful to show on every render
  # for "offline" or "no remote".
  FETCH_SEC=$((10#$(date +%S)))
  if [ $(( FETCH_SEC % 30 )) -lt 10 ]; then
    FETCH_LOCK="/tmp/.claude-statusline-fetch-$(printf '%s' "$CWD" | cksum | cut -d' ' -f1)"
    if mkdir "$FETCH_LOCK" 2>/dev/null; then
      ( git -C "$CWD" fetch --quiet >/dev/null 2>&1; rmdir "$FETCH_LOCK" 2>/dev/null ) &
      disown 2>/dev/null
    fi
  fi

  # Six file-state counts, no +/- line-diff distinction anymore (this used
  # to be `git diff --shortstat`, insertion/deletion *lines*; deliberately
  # simplified to file counts per case instead - easier to reason about six
  # consistent counts than mixing line-granularity with file-granularity).
  #
  # `status --porcelain=v2` instead of separate `diff`/`diff --cached`
  # calls: a first attempt used --diff-filter to isolate conflicts from
  # staged/unstaged, but during an active conflict git still reports the
  # conflicted path as plain "Modified" against the index - it showed up
  # double-counted as both unstaged AND conflicted (confirmed live).
  # porcelain=v2 avoids this structurally: conflicted paths are their own
  # line type ("u ...", XY like "UU"), entirely separate from ordinary
  # entries ("1 XY ..." - X=index/staged status, Y=worktree/unstaged
  # status, "." meaning no change in that dimension) - no overlap possible.
  GIT_COUNTS=$(git -C "$CWD" status --porcelain=v2 2>/dev/null | awk '
    /^\?/ { untracked++ }
    /^u / { conflict++ }
    /^1 / || /^2 / {
      if (substr($2,1,1) != ".") staged++
      if (substr($2,2,1) != ".") unstaged++
    }
    END { printf "%d %d %d %d", untracked+0, unstaged+0, staged+0, conflict+0 }
  ')
  read -r UNTRACKED_N UNSTAGED_N STAGED_N CONFLICT_N <<< "$GIT_COUNTS"

  AHEAD=0; BEHIND=0
  UPSTREAM_COUNTS=$(git -C "$CWD" rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null)
  [ -n "$UPSTREAM_COUNTS" ] && read -r AHEAD BEHIND <<< "$UPSTREAM_COUNTS"

  # Working-tree state: untracked -> unstaged -> staged, one parenthetical,
  # git's own workflow order. Each count shown only when non-zero.
  WT_PARTS=()
  [ "$UNTRACKED_N" -gt 0 ] && WT_PARTS+=("${GIT_CYAN}?${UNTRACKED_N}${GRAY_3}")
  [ "$UNSTAGED_N" -gt 0 ]  && WT_PARTS+=("!${UNSTAGED_N}")
  [ "$STAGED_N" -gt 0 ]    && WT_PARTS+=("${GIT_BLUE}✚${STAGED_N}${GRAY_3}")
  WT_SEG=""
  if [ "${#WT_PARTS[@]}" -gt 0 ]; then
    WT_JOINED=$(IFS=' '; echo "${WT_PARTS[*]}")
    WT_SEG=" (${WT_JOINED})"
  fi

  # Sync state (ahead/behind remote) - a different axis than working-tree
  # state (your history vs. the remote's, not file edits), so it sits
  # outside the parens instead of competing for space inside it.
  SYNC_SEG=""
  if [ "$AHEAD" -gt 0 ] || [ "$BEHIND" -gt 0 ]; then
    SYNC_SEG=" ${GIT_PURPLE}"
    [ "$AHEAD" -gt 0 ]  && SYNC_SEG="${SYNC_SEG}⇡${AHEAD}"
    [ "$BEHIND" -gt 0 ] && SYNC_SEG="${SYNC_SEG}⇣${BEHIND}"
    SYNC_SEG="${SYNC_SEG}${GRAY_3}"
  fi

  # Merge conflicts: the one deliberately "loud" (red) element - see the
  # GIT_* color comment above for why reusing SEV_RED here is intentional.
  CONFLICT_SEG=""
  [ "$CONFLICT_N" -gt 0 ] && CONFLICT_SEG=" ${SEV_RED}(✖${CONFLICT_N})${GRAY_3}"

  GIT_SEG="    ${GRAY_3}🌿 ${BRANCH}${WT_SEG}${SYNC_SEG}${CONFLICT_SEG}${RESET}"
fi
  jq -n --arg seg "$GIT_SEG" '{fetched_at: (now|floor), git_seg: $seg}' > "$GIT_CACHE_FILE.tmp.$$" 2>/dev/null \
    && mv "$GIT_CACHE_FILE.tmp.$$" "$GIT_CACHE_FILE"
  rmdir "$GIT_CACHE_LOCK" 2>/dev/null
elif [ -f "$GIT_CACHE_FILE" ]; then
  # Another session is already recomputing right now - stale-but-present
  # beats nothing for this one render.
  GIT_SEG=$(jq -r '.git_seg' "$GIT_CACHE_FILE" 2>/dev/null)
fi

# Host color: same idea as the git cache above, but simpler - the value
# never changes for a given hostname, so no TTL, just "compute once per
# machine, ever." Skipped entirely when $HOST_COLOR is already inherited
# from the shell (the common case, see the comment near the top).
HOST_SHORT=$(hostname -s)
STATIC_CACHE="$CACHE_DIR/static.json"
if [ -n "${HOST_COLOR:-}" ]; then
  HOST_COLOR_NUM="$HOST_COLOR"
else
  HOST_COLOR_NUM=$(jq -r '.host_color // empty' "$STATIC_CACHE" 2>/dev/null)
  if [ -z "$HOST_COLOR_NUM" ]; then
    HOST_COLOR_NUM=$(get_host_color "$HOST_SHORT" 2>/dev/null)
    # Atomic write via own tmp filename, no lock needed: the value is
    # deterministic, so two sessions racing to compute it just write the
    # same result twice, not a wrong one.
    jq -n --arg c "$HOST_COLOR_NUM" '{host_color: $c}' > "$STATIC_CACHE.tmp.$$" 2>/dev/null \
      && mv "$STATIC_CACHE.tmp.$$" "$STATIC_CACHE"
  fi
fi
HOST_COLOR_ESC="\033[38;5;${HOST_COLOR_NUM}m"

echo -e "${GRAY_1}🤖 ${MODEL_STR}${RESET}    ${HOST_COLOR_ESC}🖥️  ${HOST_SHORT}${RESET}    ${GRAY_2}📂 ${CWD}${RESET}${GIT_SEG}"

# --- line 2: session UUID (far left, for crash recovery) | rotating info ---
# Title dropped: already shown in the terminal tab/prompt-box, redundant here.
# Shell PID dropped too (2026-08-25): not critical, and `/notify` still
# surfaces it when actually needed - not worth a `ps`-walk up the process
# tree (~5-10 forks) on every single render just to have it always visible.
#
# Rotating info (was: datetime always) - same seconds-bucket trick as the
# fetch scheduler above, `(seconds / 10) % 3` cycles through 3 states every
# 30s, changing roughly in step with the ~10s refresh instead of jumping
# unpredictably. Still rotates through the reset times even while a window
# shows "Blocked" on line 3 - arguably more useful to know exactly when
# you're unblocked then, not less.
ROTATE_IDX=$(( (10#$(date +%S) / 10) % 3 ))
case "$ROTATE_IDX" in
  0)
    ROTATE_STR=$(date '+%m/%d %H:%M:%S')
    ;;
  1)
    if [ -n "$WK_RESETS" ]; then
      WK_DAY=$(fmt_epoch "$WK_RESETS" "%e" | tr -d ' ')
      ROTATE_STR="7d reset on $(fmt_epoch "$WK_RESETS" "%A") ${WK_DAY}$(ordinal_suffix "$WK_DAY") at $(fmt_epoch "$WK_RESETS" "%Hh")"
    else
      ROTATE_STR=$(date '+%m/%d %H:%M:%S')
    fi
    ;;
  2)
    if [ -n "$RL_RESETS" ]; then
      ROTATE_STR="5h reset at $(fmt_epoch "$RL_RESETS" "%Hh%M")"
    else
      ROTATE_STR=$(date '+%m/%d %H:%M:%S')
    fi
    ;;
esac

echo -e "${GRAY_4}🆔 ${SESSION_ID}    ${ROTATE_STR}${RESET}"

# --- line 3: context bar | 5h rate-limit bar | 7d rate-limit bar | memory - all colored by criticality ---
BAR_WIDTH=8

blocked_or_bar() {
  # blocked_or_bar <pct> <resets_at> <emoji> -> "<emoji> [bar] pct%" or "<emoji> Blocked - resets in Xh Ym"
  local pct=$1 resets=$2 emoji=$3
  if [ "$pct" -ge 100 ] && [ -n "$resets" ]; then
    local now remain rh rm
    now=$(date +%s); remain=$(( resets - now )); [ "$remain" -lt 0 ] && remain=0
    rh=$(( remain / 3600 )); rm=$(( (remain % 3600) / 60 ))
    printf '%b%s Blocked - resets in %dh %dm%b' "$SEV_RED" "$emoji" "$rh" "$rm" "$RESET"
  else
    local color barstr
    color=$(sev_color "$pct")
    barstr=$(bar "$pct" "$BAR_WIDTH" "$color")
    printf '%b%s %b[%s] %b%s%%%b' "$color" "$emoji" "$RESET" "$barstr" "$color" "$pct" "$RESET"
  fi
}

CTX_COLOR=$(sev_color "$CTX_PCT")
CTX_BAR=$(bar "$CTX_PCT" "$BAR_WIDTH" "$CTX_COLOR")
CTX_STR="${CTX_COLOR}💬 ${RESET}[${CTX_BAR}] ${CTX_COLOR}${CTX_PCT}%${RESET}"

RL_STR=$(blocked_or_bar "$RL_PCT" "$RL_RESETS" "5h")
WK_STR=$(blocked_or_bar "$WK_PCT" "$WK_RESETS" "7d")

if [ "$(uname -s)" = "Darwin" ]; then
  # vm_stat instead of `top -l 1`: top always walks the full process table
  # to build its summary line even with `-n 0` (display-row count only, not
  # a scan-skip flag) - measured live (2026-08-25), under real load (30-50
  # concurrent Claude Code sessions on this machine): 5-9s real, 3.5-5s sys
  # CPU per call. Gets worse as the process table grows, which is exactly
  # what's been happening - ruinous re-run every ~10s across that many
  # sessions. vm_stat reads kernel page counters directly (no per-process
  # work at all): measured at the same time, ~0.04s real, unmeasurably low
  # CPU.
  # "used" approximated as active+wired+compressed pages, matching top's
  # PhysMem definition closely enough for a decorative bar (not exact -
  # top's figure includes some additional accounting this skips).
  MEM_TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
  read -r MEM_USED MEM_TOTAL MEM_PCT <<< "$(LC_ALL=C vm_stat | awk -v totalb="$MEM_TOTAL_BYTES" '
    NR==1 { for (i=1;i<=NF;i++) if ($i=="of") { pagesize=$(i+1)+0 }; next }
    /^Pages active/ { active=$NF+0 }
    /^Pages wired down/ { wired=$NF+0 }
    /^Pages occupied by compressor/ { compressor=$NF+0 }
    END {
      usedG=(active+wired+compressor)*pagesize/1024/1024/1024
      totalG=totalb/1024/1024/1024
      pct=int(usedG/totalG*100+0.5)
      printf "%.1fG %.1fG %d", usedG, totalG, pct
    }')"
else
  # Linux: /proc/meminfo, "used" = MemTotal - MemAvailable (matches `free`'s definition).
  read -r MEM_USED MEM_TOTAL MEM_PCT <<< "$(LC_ALL=C awk '
    /^MemTotal:/{total=$2} /^MemAvailable:/{avail=$2}
    END{
      usedG=(total-avail)/1024/1024; totalG=total/1024/1024
      pct=int(usedG/totalG*100+0.5)
      printf "%.1fG %.1fG %d", usedG, totalG, pct
    }' /proc/meminfo)"
fi
MEM_COLOR=$(sev_color "$MEM_PCT")

echo -e "${CTX_STR}    ${RL_STR}    ${WK_STR}    ${MEM_COLOR}💾 ${MEM_USED}/${MEM_TOTAL}${RESET}"
