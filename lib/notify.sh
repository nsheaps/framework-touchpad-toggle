#!/usr/bin/env bash
# notify.sh — desktop notifications.
#
# All notifications are prefixed with 🖱️ to draw attention; the
# no-other-mouse warning is prefixed with 🚨🖱️ (the red siren adds colour).
#
# Notification behavior is config-driven:
#   notify_enabled        true|false
#   notify_timeout_ms     integer (0 = use notifier default)
#   notify_warn_persistent true|false  (warning stays until dismissed)

FTT_EMOJI="🖱️"
FTT_EMOJI_WARN="🚨🖱️"

ftt::_notify_enabled() {
  [ "$(ftt::config_get notify_enabled true)" = "true" ]
}

# ftt::_send <urgency> <timeout-ms> <summary> <body>
ftt::_send() {
  local urgency="$1" timeout="$2" summary="$3" body="$4"
  if ftt::have notify-send; then
    local args=(--app-name "framework-touchpad-toggle" --urgency "$urgency")
    [ "$timeout" -gt 0 ] 2>/dev/null && args+=(--expire-time "$timeout")
    notify-send "${args[@]}" "$summary" "$body" 2>/dev/null ||
      printf '%s %s\n' "$summary" "$body"
  else
    # Headless / no notifier: fall back to stderr so nothing is lost.
    printf '%s %s\n' "$summary" "$body" >&2
  fi
}

# ftt::notify <enable|disable|...> <message>
ftt::notify() {
  ftt::_notify_enabled || return 0
  local timeout
  timeout="$(ftt::config_get notify_timeout_ms 2000)"
  ftt::_send normal "$timeout" "$FTT_EMOJI Touchpad" "$2"
}

# ftt::notify_warn <message> — the "no other mouse" warning.
ftt::notify_warn() {
  ftt::_notify_enabled || {
    # Even if normal notifications are off, a pointer-loss warning is
    # important enough to still surface on stderr.
    printf '%s %s\n' "$FTT_EMOJI_WARN" "$1" >&2
    return 0
  }
  local timeout urgency
  if [ "$(ftt::config_get notify_warn_persistent false)" = "true" ]; then
    timeout=0
    urgency=critical
  else
    timeout="$(ftt::config_get notify_timeout_ms 2000)"
    urgency=critical
  fi
  ftt::_send "$urgency" "$timeout" "$FTT_EMOJI_WARN Touchpad disabled" "$1"
}
