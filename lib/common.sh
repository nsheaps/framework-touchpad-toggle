#!/usr/bin/env bash
# common.sh — shared helpers: logging, platform detection, guards.
# Sourced by bin/framework-touchpad-toggle. Not executable on its own.

# --- logging ----------------------------------------------------------------
ftt::err() { printf 'framework-touchpad-toggle: %s\n' "$*" >&2; }
ftt::warn() { printf 'framework-touchpad-toggle: warning: %s\n' "$*" >&2; }
ftt::info() {
  [ "${FTT_QUIET:-false}" = "true" ] && return 0
  printf '%s\n' "$*"
}
ftt::die() {
  ftt::err "$*"
  exit 1
}

# --- platform gating --------------------------------------------------------
# These are runtime checks. The Homebrew formula warns (does not fatal) on
# non-Framework / non-Debian so that `brew install` still works in CI; the
# hard failure happens here, when the tool is actually invoked.

ftt::require_linux() {
  [ "$(uname -s)" = "Linux" ] || ftt::die "this tool only runs on Linux."
}

ftt::is_debian_like() {
  [ -f /etc/debian_version ] && return 0
  [ -r /etc/os-release ] && grep -Eq '^ID(_LIKE)?=.*debian' /etc/os-release && return 0
  return 1
}

ftt::is_framework() {
  local vendor=""
  [ -r /sys/class/dmi/id/sys_vendor ] &&
    vendor="$(tr -d '[:space:]' </sys/class/dmi/id/sys_vendor)"
  [ "$vendor" = "Framework" ]
}

# Soft preflight — warns, never exits. Called before actions.
ftt::preflight() {
  ftt::require_linux
  ftt::is_debian_like ||
    ftt::warn "this is not a Debian-based distro; behavior is untested here."
  ftt::is_framework ||
    ftt::warn "this does not look like a Framework laptop; behavior is untested here."
}

# --- misc -------------------------------------------------------------------
ftt::have() { command -v "$1" >/dev/null 2>&1; }

# Prompt helper. Honors --preserve/--force (non-interactive).
# ftt::confirm "question" <default-yes|default-no>
ftt::confirm() {
  local q="$1" def="${2:-default-no}"
  if [ "${FTT_FORCE:-false}" = "true" ]; then return 0; fi
  if [ "${FTT_PRESERVE:-false}" = "true" ]; then
    [ "$def" = "default-yes" ]
    return
  fi
  local suffix="[y/N]"
  [ "$def" = "default-yes" ] && suffix="[Y/n]"
  local ans
  read -r -p "$q $suffix " ans || true
  ans="${ans:-}"
  if [ -z "$ans" ]; then
    [ "$def" = "default-yes" ]
    return
  fi
  [[ "$ans" =~ ^[Yy] ]]
}
