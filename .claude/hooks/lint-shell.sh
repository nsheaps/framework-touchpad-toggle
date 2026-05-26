#!/usr/bin/env bash
# PostToolUse hook: lint shell sources after any edit. Non-blocking —
# prints findings but exits 0 so it never interrupts the session.
set -uo pipefail
files=(bin/framework-touchpad-toggle lib/*.sh test/*.sh)
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x -e SC1090,SC1091 "${files[@]}" 2>&1 || true
fi
if command -v shfmt >/dev/null 2>&1; then
  shfmt -d -i 2 -ci "${files[@]}" 2>&1 || true
fi
exit 0
