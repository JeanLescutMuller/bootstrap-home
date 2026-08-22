#!/bin/bash
# Custom Claude Code status line.
# Reads the hook JSON payload from stdin (see Claude Code docs for the schema);
# fields used here were confirmed by capturing a live payload on 2026-08-18.

input=$(cat)

RESET='\033[0m'

# --- lines 1-2: grayscale, brightness = importance ---
GRAY_1='\033[97m'       # bright white  - model+effort (most important)
GRAY_2='\033[37m'       # white         - cwd, session title
GRAY_3='\033[38;5;250m' # light gray    - git branch/diff
GRAY_4='\033[38;5;240m' # dark gray     - session uuid (crash-recovery only)
GRAY_5='\033[38;5;236m' # darkest gray  - shell pid (least important)

# --- line 3: criticality colors (green/yellow/red by severity) ---
SEV_GREEN='\033[32m'; SEV_YELLOW='\033[33m'; SEV_RED='\033[31m'
BAR_EMPTY='\033[38;5;238m' # dim track for the unfilled part of a bar

# --- line 1: host identity, hashed color (deliberately not hardcoded) ---
# A hostname->color lookup table would leave every new machine on an
# "undefined" color until someone edits this script and redeploys it
# everywhere - hashing gives any hostname a stable color the moment this
# first runs there, no maintenance. SHA-256, not cksum: cksum is a CRC,
# fine for error-detection but reducing it mod a small bucket count
# clusters badly (verified: "mac" and "H-Frank-1" landed on the exact
# same bucket with cksum %6). 14 shades keeps collisions rare across a
# handful of real machines - kept entirely in the blue/purple/cyan
# family, deliberately out of the green/yellow/red severity language
# used on line 3, so it never reads as a status signal.
HOST_PALETTE=(25 27 33 39 45 51 50 44 57 63 99 129 135 141)
host_color() {
  local host="$1" hex dec
  if command -v sha256sum >/dev/null 2>&1; then
    hex=$(printf '%s' "$host" | sha256sum | cut -c1-8)
  else
    hex=$(printf '%s' "$host" | shasum -a 256 | cut -c1-8)
  fi
  dec=$((16#$hex))
  echo "\033[38;5;${HOST_PALETTE[$(( dec % ${#HOST_PALETTE[@]} ))]}m"
}

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

# --- walk up the process tree to find the enclosing shell PID ---
# Claude Code invokes statusLine.command via `sh -c "..."`, so the immediate
# parent is always a throwaway interpreter shell, not the real login shell
# hosting this session - confirmed live (2026-08-22): the ancestor chain is
# always statusline's bash -> throwaway sh -> claude -> REAL login shell ->
# tmux server. Keep walking past that first match instead of stopping there,
# so `found` ends up holding the outermost (real) shell, not the innermost
# (throwaway) one.
find_shell_pid() {
  local walk_pid=$PPID walk_cmd found=""
  while [ -n "$walk_pid" ] && [ "$walk_pid" -gt 1 ]; do
    walk_cmd=$(ps -o comm= -p "$walk_pid" 2>/dev/null | tr -d ' ')
    walk_cmd="${walk_cmd##*/}"
    walk_cmd="${walk_cmd#-}"
    case "$walk_cmd" in
      bash|zsh|sh|fish|dash|tcsh|csh) found="$walk_pid" ;;
    esac
    walk_pid=$(ps -o ppid= -p "$walk_pid" 2>/dev/null | tr -d ' ')
  done
  echo "$found"
}

# --- parse payload ---
MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
CWD=$(echo "$input" | jq -r '.cwd')
SESSION_ID=$(echo "$input" | jq -r '.session_id')
SESSION_NAME=$(echo "$input" | jq -r '.session_name // empty')

CTX_PCT=$(echo "$input" | jq -r '(.context_window.used_percentage // 0) | round')

RL_PCT=$(echo "$input" | jq -r '(.rate_limits.five_hour.used_percentage // 0) | round')
RL_RESETS=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

WK_PCT=$(echo "$input" | jq -r '(.rate_limits.seven_day.used_percentage // 0) | round')
WK_RESETS=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

SHELL_PID=$(find_shell_pid)

# --- line 1: model+effort | cwd | git (only if inside a repo) ---
MODEL_STR="${MODEL}"
[ -n "$EFFORT" ] && MODEL_STR="${MODEL} (${EFFORT})"

GIT_SEG=""
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && BRANCH=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)

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

DATETIME=$(date '+%m/%d %H:%M:%S')

HOST_SHORT=$(hostname -s)
HOST_COLOR=$(host_color "$HOST_SHORT")

echo -e "${GRAY_1}🤖 ${MODEL_STR}${RESET}    ${HOST_COLOR}🖥️  ${HOST_SHORT}${RESET}    ${GRAY_2}📂 ${CWD}${RESET}${GIT_SEG}    ${GRAY_4}${DATETIME}${RESET}"

# --- line 2: session UUID (far left, for crash recovery) | session title | shell pid ---
TITLE_SEG=""
[ -n "$SESSION_NAME" ] && TITLE_SEG="    ${GRAY_2}🏷️  ${SESSION_NAME}${RESET}"

echo -e "${GRAY_4}🆔 ${SESSION_ID}${RESET}${TITLE_SEG}    ${GRAY_5}⚙️  ${SHELL_PID}${RESET}"

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
  MEM_RAW=$(top -l 1 -s 0 -n 0 2>/dev/null | awk -F'[ ,]+' '/^PhysMem/{for(i=1;i<=NF;i++) if($i=="used") print $(i-1)}')
  MEM_TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
  read -r MEM_USED MEM_TOTAL MEM_PCT <<< "$(LC_ALL=C awk -v raw="$MEM_RAW" -v totalb="$MEM_TOTAL_BYTES" 'BEGIN{
    unit=substr(raw,length(raw),1); usedG=substr(raw,1,length(raw)-1)+0
    if (unit=="M") usedG/=1024
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
