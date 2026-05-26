#!/usr/bin/env bash
# session.sh — detect the display session and enable/disable the touchpad.
#
# X11:     per-device control via `xinput` (targets ONLY the configured pad).
# Wayland: GNOME has no per-device xinput; we use the GNOME gsettings key
#          `org.gnome.desktop.peripherals.touchpad send-events`. That key
#          targets the internal touchpad; true per-device targeting is not
#          possible under Wayland, so we warn when an external touchpad
#          would also be affected.

ftt::session_type() {
  if [ -n "${FTT_SESSION:-}" ]; then
    printf '%s\n' "$FTT_SESSION"
    return
  fi
  local t="${XDG_SESSION_TYPE:-}"
  if [ -z "$t" ]; then
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
      t="wayland"
    elif [ -n "${DISPLAY:-}" ]; then
      t="x11"
    else
      t="unknown"
    fi
  fi
  printf '%s\n' "$t"
}

ftt::is_gnome() {
  case "${XDG_CURRENT_DESKTOP:-}" in
    *GNOME* | *gnome* | *Unity*) return 0 ;;
  esac
  printf '%s' "${DESKTOP_SESSION:-}" | grep -qi gnome
}

# --- query current state: echoes "enabled" | "disabled" ---------------------
ftt::touchpad_state() {
  case "$(ftt::session_type)" in
    x11) ftt::_state_x11 ;;
    wayland) ftt::_state_wayland ;;
    *)
      ftt::warn "unknown session type; assuming Wayland/gsettings."
      ftt::_state_wayland
      ;;
  esac
}

ftt::_state_x11() {
  local node id
  node="$(ftt::target_touchpad_node)"
  if [ -z "$node" ]; then
    ftt::warn "configured touchpad not currently present."
    echo "disabled"
    return
  fi
  ftt::have xinput || ftt::die "xinput not found; install the 'xinput' package."
  id="$(ftt::_xinput_id_for_node "$node")"
  [ -z "$id" ] && {
    echo "disabled"
    return
  }
  if xinput list-props "$id" 2>/dev/null |
    grep -Eq 'Device Enabled.*:[[:space:]]*1'; then
    echo "enabled"
  else
    echo "disabled"
  fi
}

ftt::_state_wayland() {
  ftt::have gsettings || ftt::die "gsettings not found."
  local v
  v="$(gsettings get org.gnome.desktop.peripherals.touchpad send-events 2>/dev/null || echo "'enabled'")"
  case "$v" in
    *disabled*) echo "disabled" ;;
    *) echo "enabled" ;;
  esac
}

# --- apply state: ftt::touchpad_set <enable|disable> ------------------------
ftt::touchpad_set() {
  local want="$1"
  case "$(ftt::session_type)" in
    x11) ftt::_set_x11 "$want" ;;
    wayland) ftt::_set_wayland "$want" ;;
    *)
      ftt::warn "unknown session type; using Wayland/gsettings path."
      ftt::_set_wayland "$want"
      ;;
  esac
}

ftt::_set_x11() {
  local want="$1" node id
  ftt::have xinput || ftt::die "xinput not found; install the 'xinput' package."
  node="$(ftt::target_touchpad_node)"
  [ -z "$node" ] && ftt::die "configured touchpad is not connected."
  id="$(ftt::_xinput_id_for_node "$node")"
  [ -z "$id" ] && ftt::die "could not map touchpad to an xinput device id."
  if [ "$want" = "enable" ]; then
    xinput enable "$id"
  else
    xinput disable "$id"
  fi
}

ftt::_set_wayland() {
  local want="$1"
  ftt::have gsettings || ftt::die "gsettings not found."
  ftt::is_gnome || ftt::warn "non-GNOME Wayland session; gsettings may have no effect."
  # Wayland cannot target a single device; warn if an external touchpad exists.
  if ftt::_has_external_touchpad; then
    ftt::warn "Wayland cannot target one device; this affects ALL internal touchpads."
  fi
  if [ "$want" = "enable" ]; then
    gsettings set org.gnome.desktop.peripherals.touchpad send-events 'enabled'
  else
    gsettings set org.gnome.desktop.peripherals.touchpad send-events 'disabled'
  fi
}

# True if a touchpad other than the configured target is present.
ftt::_has_external_touchpad() {
  local target class id node _label
  target="$(ftt::target_touchpad_id)"
  while IFS=$'\t' read -r class id node _label; do
    [ "$class" = "touchpad" ] || continue
    [ "$id" = "$target" ] && continue
    return 0
  done < <(ftt::devices_enumerate)
  return 1
}

# Map an evdev node to an xinput numeric id by matching the device name.
ftt::_xinput_id_for_node() {
  local node="$1" name
  name="$(cat "/sys/class/input/$(basename "$node")/device/name" 2>/dev/null || true)"
  [ -z "$name" ] && return 0
  # xinput lists by name; pick the pointer entry that matches.
  xinput list --name-only 2>/dev/null | grep -Fx "$name" >/dev/null || true
  xinput list 2>/dev/null |
    grep -F "$name" |
    grep -Eo 'id=[0-9]+' | head -n1 | cut -d= -f2
}
