#!/bin/bash
# ol.sh - call one tool of the Outlook MCP server (Softeria ms-365-mcp-server, the audited version
# below) from the shell, through the MCP inspector CLI. Read-only unless --write.
#
#   ol.sh [--write] <tool> [key=value ...]   one tool call; prints the MCP JSON result
#   ol.sh [--write] --list                   the tools and their parameters (tools/list)
#   ol.sh [--write] --login | --verify-login | --list-accounts | --list-permissions
#                                            the server's own commands (sign-in, checks)
#
# Values are JSON-parsed by the inspector (numbers, true, objects); pass account=<email>.
# The payload is JSON.parse(result.content[0].text). Each call takes ~3-5 s (two npx starts).
set -euo pipefail

VERSION=0.157.2              # audited 2026-10-14: upgrade only after a new audit (SKILL.md)
INSPECTOR=0.17.2             # same inspector as skill linkedin
export MS365_MCP_TENANT_ID=consumers npm_config_ignore_scripts=true

mode=(--read-only)
if [ "${1:-}" = --write ]; then mode=(); shift; fi
[ $# -ge 1 ] || { sed -n '5,10p' "$0"; exit 2; }

server=(npx -y "@softeria/ms-365-mcp-server@$VERSION" --preset mail ${mode[@]+"${mode[@]}"})
inspector=(npx -y "@modelcontextprotocol/inspector@$INSPECTOR" --cli)

case "$1" in
    --list) exec "${inspector[@]}" "${server[@]}" --method tools/list ;;
    --*)    exec "${server[@]}" "$@" ;;
esac

tool=$1; shift
args=()
for kv in "$@"; do args+=(--tool-arg "$kv"); done
exec "${inspector[@]}" "${server[@]}" --method tools/call --tool-name "$tool" ${args[@]+"${args[@]}"}
