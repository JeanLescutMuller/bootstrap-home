#!/bin/bash
# Check a project's documentation against the documentation-writing skill.
#
# Usage: bash check_docs.sh [project-root]      (default: current directory)
# Prints one line per finding (FAIL must be fixed, WARN should be looked at),
# then a summary. Exits 1 if any FAIL. Read-only: never changes a file.
set -uo pipefail

ROOT="$(cd "${1:-.}" && pwd)" || exit 2
AGENTS_WARN_WORDS=400
AGENTS_FAIL_WORDS=600
CHAIN_WARN_WORDS=1900

n_fail=0
n_warn=0
fail() { echo "FAIL  ${1#"$ROOT"/}: $2"; n_fail=$((n_fail + 1)); }
warn() { echo "WARN  ${1#"$ROOT"/}: $2"; n_warn=$((n_warn + 1)); }

# The file list, built once. In a git repo: tracked + untracked files that
# .gitignore does not exclude (fast, and skips data folders); otherwise find,
# skipping vendored and generated trees.
ALL_FILES="$(mktemp)"
trap 'rm -f "$ALL_FILES"' EXIT
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" ls-files -co --exclude-standard | grep -vxF -f <(git -C "$ROOT" ls-files -d) |
        awk -v r="$ROOT" '{ print r "/" $0 }' > "$ALL_FILES"
else
    find "$ROOT" \( -name .git -o -name node_modules -o -name .venv -o -name venv \
        -o -name __pycache__ -o -name .ipynb_checkpoints \) -prune -o \( -type f -o -type l \) -print > "$ALL_FILES"
fi

# Every listed file whose basename matches the regex $1.
find_named() {
    grep -E "/$1\$" "$ALL_FILES"
}

# Prints the file with fenced code blocks and HTML comments blanked out,
# keeping one output line per input line so line numbers stay true.
strip_fences() {
    awk '
        /^[[:space:]]*```/ { f = !f; print ""; next }
        f { print ""; next }
        {
            line = $0; out = ""
            while (line != "") {
                if (c) { i = index(line, "-->"); if (!i) { line = ""; break } line = substr(line, i + 3); c = 0 }
                else { i = index(line, "<!--"); if (!i) { out = out line; break } out = out substr(line, 1, i - 1); line = substr(line, i + 4); c = 1 }
            }
            print out
        }' "$1"
}

[ -f "$ROOT/AGENTS.md" ] || warn "$ROOT/." "no AGENTS.md at the project root"

# --- AGENTS.md: symlink, budgets, README beside it ---
while IFS= read -r agents; do
    dir="$(dirname "$agents")"
    claude="$dir/CLAUDE.md"
    if [ ! -e "$claude" ] && [ ! -L "$claude" ]; then
        fail "$claude" "missing — run: ln -sfn AGENTS.md CLAUDE.md"
    elif [ ! -L "$claude" ]; then
        fail "$claude" "is a real file, must be a symlink to AGENTS.md"
    elif [ "$(readlink "$claude")" != "AGENTS.md" ]; then
        fail "$claude" "points to '$(readlink "$claude")', must point to AGENTS.md"
    else
        mode="$(git -C "$dir" ls-files -s CLAUDE.md 2>/dev/null | awk '{print $1}')"
        [ -n "$mode" ] && [ "$mode" != "120000" ] && fail "$claude" "git mode $mode, must be 120000 (a symlink)"
    fi

    words="$(wc -w < "$agents" | tr -d ' ')"
    if [ "$words" -gt "$AGENTS_FAIL_WORDS" ]; then
        fail "$agents" "$words words (> $AGENTS_FAIL_WORDS): move explanations to doc/ or TODO.md"
    elif [ "$words" -gt "$AGENTS_WARN_WORDS" ]; then
        warn "$agents" "$words words (aim ≤ $AGENTS_WARN_WORDS)"
    fi

    chain=0
    p="$dir"
    while :; do
        [ -f "$p/AGENTS.md" ] && chain=$((chain + $(wc -w < "$p/AGENTS.md")))
        { [ "$p" = "$ROOT" ] || [ "$p" = "/" ]; } && break
        p="$(dirname "$p")"
    done
    [ "$chain" -gt "$CHAIN_WARN_WORDS" ] && warn "$agents" "loaded chain is $chain words (aim ≤ $CHAIN_WARN_WORDS)"

    if [ -f "$dir/README.html" ] && [ ! -f "$dir/README.md" ]; then
        fail "$dir/README.html" "needs a short README.md stub linking to it"
    elif [ ! -f "$dir/README.md" ]; then
        warn "$dir/." "has AGENTS.md but no README.md / README.html"
    fi

    # A paired README holds entities only: no imperatives, no tunable numbers.
    if [ -f "$dir/README.md" ]; then
        while IFS= read -r hit; do
            warn "$dir/README.md" "line ${hit%%:*} looks like a rule or a tunable number (belongs in AGENTS.md)"
        done < <(strip_fences "$dir/README.md" |
            grep -nE "\b(do not|don't|must not|never edit|always run)\b|\b[0-9]+ ?(s|ms|min|%|GB|MB|bps)\b")
    fi
done < <(find_named 'AGENTS\.md')

# --- CLAUDE.md with no AGENTS.md beside it ---
while IFS= read -r claude; do
    [ -e "$(dirname "$claude")/AGENTS.md" ] ||
        warn "$claude" "no AGENTS.md beside it: move its content into AGENTS.md, then symlink"
done < <(find_named 'CLAUDE\.md')

# --- doc/ folders never hold a README ---
while IFS= read -r readme; do
    [ "$(basename "$(dirname "$readme")")" = "doc" ] &&
        fail "$readme" "a doc/ folder never holds a README.md — index it from the parent README"
done < <(find_named 'README\.md')

# --- TODO.md holds open items only ---
while IFS= read -r todo; do
    while IFS= read -r hit; do
        warn "$todo" "line ${hit%%:*} keeps a done item — delete it (rule → AGENTS.md, evidence → doc/)"
    done < <(strip_fences "$todo" | grep -nE '^#+ .*\b(Done|Completed|Resolved|Archive)\b|✅|~~[^~]+~~')
done < <(find_named 'TODO\.md')

# --- relative Markdown links resolve (templates are skipped: their links
# are meant for the project they get copied into) ---
while IFS= read -r md; do
    case "$md" in *.template.md) continue ;; esac
    dir="$(dirname "$md")"
    while IFS=$'\t' read -r lineno target; do
        case "$target" in
            http:* | https:* | mailto:* | \#* | *'<'* | '~'*) continue ;;
        esac
        target="${target%% *}"
        target="${target%%#*}"
        [ -z "$target" ] && continue
        [ -e "$dir/$target" ] || fail "$md" "line $lineno: broken link → $target"
    done < <(strip_fences "$md" |
        awk '{ line = $0; gsub(/`[^`]*`/, "", line); while (match(line, /\]\([^)]+\)/)) { print NR "\t" substr(line, RSTART + 2, RLENGTH - 3); line = substr(line, RSTART + RLENGTH) } }')
done < <(find_named '[^/]+\.md')

echo "---"
echo "$n_fail FAIL, $n_warn WARN  ($ROOT)"
[ "$n_fail" -eq 0 ]
