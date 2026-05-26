#!/usr/bin/env bash
# config.sh — read/write the stable, version-independent config file.
#
# Format: simple INI-ish key=value, with `#` comment lines. We keep it
# hand-rolled (no toml dependency) but comment-preserving for the
# device sections so the auto-generated human-readable comments survive.
#
# Config location follows the XDG spec and is intentionally NOT tied to
# the formula version, so upgrades reuse the same file:
#   ${XDG_CONFIG_HOME:-~/.config}/framework-touchpad-toggle/config.ini
# Override with FTT_CONFIG_FILE.

ftt::config_dir() {
  printf '%s/framework-touchpad-toggle' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

ftt::config_file() {
  if [ -n "${FTT_CONFIG_FILE:-}" ]; then
    printf '%s\n' "$FTT_CONFIG_FILE"
  else
    printf '%s/config.ini\n' "$(ftt::config_dir)"
  fi
}

ftt::config_exists() {
  [ -f "$(ftt::config_file)" ]
}

# ftt::config_get <key> [default]
# Reads the last non-comment `key=value` for <key> from the [settings] area.
ftt::config_get() {
  local key="$1" def="${2:-}" file
  file="$(ftt::config_file)"
  [ -f "$file" ] || {
    printf '%s' "$def"
    return 0
  }
  local val
  val="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null |
    grep -v '^[[:space:]]*#' | tail -n1 | sed -E 's/^[^=]*=[[:space:]]*//')"
  if [ -z "$val" ]; then
    printf '%s' "$def"
  else
    printf '%s' "$val"
  fi
}

# ftt::config_set <key> <value> — idempotent upsert into [settings].
ftt::config_set() {
  local key="$1" value="$2" file tmp
  file="$(ftt::config_file)"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp="$(mktemp)"
  if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -E "s|^([[:space:]]*${key}[[:space:]]*=).*|\1${value}|" "$file" >"$tmp"
  else
    cat "$file" >"$tmp"
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi
  mv "$tmp" "$file"
  chmod 0600 "$file"
}

ftt::config_require() {
  ftt::preflight
  if ! ftt::config_exists; then
    ftt::err "no config found at $(ftt::config_file)"
    ftt::err "run: framework-touchpad-toggle configure"
    exit 3
  fi
}

# Write the initial config skeleton with header comments.
ftt::config_init_skeleton() {
  local file
  file="$(ftt::config_file)"
  mkdir -p "$(dirname "$file")"
  if [ -f "$file" ]; then return 0; fi
  cat >"$file" <<EOF
# framework-touchpad-toggle configuration
# This file is intentionally version-independent: upgrades reuse it.
# Edit by hand or re-run: framework-touchpad-toggle configure
#
# [settings]
EOF
  chmod 0600 "$file"
}

# --- device ignore-list -----------------------------------------------------
# Stored as repeated `ignore_device=<stable-id>` lines, each preceded by an
# auto-generated `# <human readable description>` comment line.

ftt::config_ignored_ids() {
  local file
  file="$(ftt::config_file)"
  [ -f "$file" ] || return 0
  grep -E '^[[:space:]]*ignore_device[[:space:]]*=' "$file" 2>/dev/null |
    sed -E 's/^[^=]*=[[:space:]]*//'
}

# ftt::config_add_ignored <stable-id> <human-comment>
ftt::config_add_ignored() {
  local id="$1" comment="$2" file
  file="$(ftt::config_file)"
  ftt::config_init_skeleton
  if ftt::config_ignored_ids | grep -Fxq "$id"; then
    return 0
  fi
  {
    printf '# %s\n' "$comment"
    printf 'ignore_device=%s\n' "$id"
  } >>"$file"
  chmod 0600 "$file"
}

# Replace the entire "last seen devices" block. Called on every
# enable/disable/startup so the config always reflects the most recent scan.
# Args: <event-label> followed by lines on stdin of: "<id>\t<comment>".
ftt::config_write_seen_block() {
  local event="$1" file tmp
  file="$(ftt::config_file)"
  ftt::config_init_skeleton
  tmp="$(mktemp)"
  # copy everything up to (not including) the seen block marker
  awk '/^# >>> last-seen-devices/{exit} {print}' "$file" >"$tmp"
  {
    printf '# >>> last-seen-devices (auto-generated, do not edit) >>>\n'
    printf '# updated: %s  event: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$event"
    local id comment
    while IFS=$'\t' read -r id comment; do
      [ -z "$id" ] && continue
      printf '# %s\n' "$comment"
      printf 'last_seen_device=%s\n' "$id"
    done
    printf '# <<< last-seen-devices <<<\n'
  } >>"$tmp"
  mv "$tmp" "$file"
  chmod 0600 "$file"
}
