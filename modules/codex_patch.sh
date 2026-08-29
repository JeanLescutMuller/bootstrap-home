#!/bin/bash
# Keep the locally patched Codex binary reproducible on supported versions.
step "codex status-line patch"

if [ "$INSTALL" != "true" ]; then
    skip "Codex status-line patch (install mode required)"
elif ! command -v codex >/dev/null 2>&1; then
    skip "Codex status-line patch (Codex not installed)"
elif bash "$SCRIPT_DIR/scripts/install-codex-statusline-patch.sh"; then
    ok "Codex status-line patch"
else
    fail "Codex status-line patch"
fi
