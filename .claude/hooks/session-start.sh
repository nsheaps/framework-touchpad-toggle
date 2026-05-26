#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Onboards the `framework-touchpad-toggle` repo. The mise plugin's own
# SessionStart hook handles the toolchain install (mise.toml).
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

echo "[session-start] onboarding framework-touchpad-toggle in ${PWD}"
echo "[session-start] done"
exit 0
