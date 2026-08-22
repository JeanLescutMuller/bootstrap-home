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
# (same algorithm as notify's fallback PID-walk: release_v4/notify, "resolve_and_run" section)
find_shell_pid() {
  local walk_pid=$PPID walk_cmd found=""
  while [ -n "$walk_pid" ] && [ "$walk_pid" -gt 1 ]; do
    walk_cmd=$(ps -o comm= -p "$walk_pid" 2>/dev/null | tr -d ' ')
    walk_cmd="${walk_cmd##*/}"
    walk_cmd="${walk_cmd#-}"
    case "$walk_cmd" in
      bash|zsh|sh|fish|dash|tcsh|csh) found="$walk_pid"; break ;;
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
  STAT=$(git -C "$CWD" diff --shortstat HEAD 2>/dev/null || git -C "$CWD" diff --shortstat 2>/dev/null)
  ADDED=$(echo "$STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
  REMOVED=$(echo "$STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
  DIFF_STR=""
  [ -n "$ADDED" ] && DIFF_STR="${DIFF_STR}+${ADDED}"
  [ -n "$REMOVED" ] && DIFF_STR="${DIFF_STR} -${REMOVED}"
  GIT_SEG="    ${GRAY_3}🌿 ${BRANCH}${DIFF_STR:+ (${DIFF_STR})}${RESET}"
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
