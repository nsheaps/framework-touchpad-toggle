#!/usr/bin/env bash
# Smoke tests — exercise the CLI surface without touching real hardware.
# Runs in CI on plain Linux (no Framework, no GNOME), so it only checks
# paths that work everywhere: help, version, config-path, arg parsing.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$here/bin/framework-touchpad-toggle"
fail=0

# check_out <desc> <needle> <args...>
# Captures BOTH stdout and stderr; tolerates non-zero exit codes.
check_out() {
  local desc="$1" needle="$2"
  shift 2
  local out
  out="$(bash "$bin" "$@" 2>&1)" || true
  if printf '%s' "$out" | grep -qF "$needle"; then
    echo "ok   - $desc"
  else
    echo "FAIL - $desc (expected '$needle')"
    fail=1
  fi
}

# check_exit <desc> <expected-rc> <args...>
check_exit() {
  local desc="$1" want="$2"
  shift 2
  local rc=0
  bash "$bin" "$@" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq "$want" ]; then
    echo "ok   - $desc (exit $rc)"
  else
    echo "FAIL - $desc (exit $rc, expected $want)"
    fail=1
  fi
}

export FTT_CONFIG_FILE
FTT_CONFIG_FILE="$(mktemp -d)/config.ini"

check_out "version" "framework-touchpad-toggle 0.1.0" --version
check_out "help" "Usage:" help
check_out "config-path" "config.ini" config-path
check_out "bad command msg" "unknown command" not-a-command
check_exit "bad command exit" 2 not-a-command
check_out "bad option msg" "unknown option" toggle --nope
check_exit "bad option exit" 2 toggle --nope
check_out "no-config message" "no config found" status

# status with no config must exit 3 (config missing) — unless the CI host
# happens to be a fully configured Framework laptop, which it is not.
check_exit "no-config exit" 3 status

if [ "$fail" -eq 0 ]; then
  echo "All smoke tests passed."
else
  echo "Smoke tests FAILED."
  exit 1
fi
