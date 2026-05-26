#!/usr/bin/env bash
# devices.sh — enumerate touchpad and mouse devices and give each a STABLE,
# per-unit identifier (not just model/vendor) plus a human-readable label.
#
# Strategy:
#   * Enumerate evdev devices via /sys/class/input/event*.
#   * Classify as touchpad / mouse / other by capabilities + name.
#   * Stable ID, in order of preference:
#       udev ID_PATH + ID_SERIAL (USB devices with a serial)
#       udev ID_PATH only        (USB devices without a serial — port-bound)
#       device PHYS string       (internal i2c devices, e.g. i2c-PIXA3854:00)
#   * Human label = device name + a hint about how unique the ID is.
#
# Output of ftt::devices_enumerate (one device per line, TAB-separated):
#   <class>\t<stable-id>\t<event-node>\t<human-label>

# Resolve udev properties for an event node into KEY=VALUE lines.
ftt::_udev_props() {
  local node="$1"
  if ftt::have udevadm; then
    udevadm info --query=property --name="$node" 2>/dev/null
  fi
}

# ftt::_prop <props-blob> <KEY>
ftt::_prop() {
  printf '%s\n' "$1" | grep -E "^$2=" | head -n1 | cut -d= -f2-
}

# Compute (stable-id, label, port-bound?) for one event node.
# Echoes: <stable-id>\t<label>
ftt::_identify() {
  local node="$1" name="$2" props id label serial idpath phys

  props="$(ftt::_udev_props "$node")"
  idpath="$(ftt::_prop "$props" ID_PATH)"
  serial="$(ftt::_prop "$props" ID_SERIAL_SHORT)"
  [ -z "$serial" ] && serial="$(ftt::_prop "$props" ID_SERIAL)"

  # phys from sysfs (e.g. "i2c-PIXA3854:00" or "usb-0000:00:14.0-4/input0")
  phys=""
  [ -r "/sys/class/input/$(basename "$node")/device/../phys" ] &&
    phys="$(tr -d '"' <"/sys/class/input/$(basename "$node")/device/../phys" 2>/dev/null || true)"

  if [ -n "$idpath" ] && [ -n "$serial" ]; then
    id="path:${idpath}|serial:${serial}"
    label="${name} (serial ${serial})"
  elif [ -n "$idpath" ]; then
    id="path:${idpath}"
    label="${name} (port-bound: ${idpath} — no serial; ID follows the USB port)"
  elif [ -n "$phys" ]; then
    id="phys:${phys}"
    label="${name} (internal: ${phys})"
  else
    id="node:$(basename "$node")"
    label="${name} (unstable: identified only by kernel event node)"
  fi
  printf '%s\t%s\n' "$id" "$label"
}

# Classify a device by its sysfs capabilities + name.
# Echoes: touchpad | mouse | other
ftt::_classify() {
  local evdir="$1" name="$2" lname
  lname="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  case "$lname" in
    *touchpad* | *trackpad* | *"glide point"*)
      echo touchpad
      return
      ;;
  esac
  # capability heuristic: touchpads expose ABS + BTN_TOOL_FINGER; mice are REL.
  local props
  props="$(cat "$evdir/device/capabilities/abs" 2>/dev/null || echo 0)"
  if [ "$props" != "0" ] && printf '%s' "$lname" | grep -q 'mouse'; then
    echo mouse
    return
  fi
  case "$lname" in
    *mouse* | *trackball* | *"usb receiver"*)
      echo mouse
      return
      ;;
  esac
  echo other
}

# Main enumerator. Prints: class \t stable-id \t event-node \t label
ftt::devices_enumerate() {
  local ev evbase name evdir class ident
  for ev in /dev/input/event*; do
    [ -e "$ev" ] || continue
    evbase="$(basename "$ev")"
    evdir="/sys/class/input/$evbase"
    name="$(cat "$evdir/device/name" 2>/dev/null || true)"
    [ -z "$name" ] && continue
    class="$(ftt::_classify "$evdir" "$name")"
    [ "$class" = "other" ] && continue
    ident="$(ftt::_identify "$ev" "$name")"
    printf '%s\t%s\t%s\n' "$class" "$ident" "$ev"
  done
}

# Pretty listing for the `list-devices` command.
ftt::devices_print_all() {
  ftt::preflight
  local class id node label
  ftt::info "Detected pointer devices:"
  ftt::info ""
  while IFS=$'\t' read -r class id node label; do
    [ -z "$class" ] && continue
    printf '  [%-8s] %s\n' "$class" "$label"
    printf '             id:   %s\n' "$id"
    printf '             node: %s\n' "$node"
    printf '\n'
  done < <(ftt::devices_enumerate)
}

# The configured touchpad's stable id (target of enable/disable).
ftt::target_touchpad_id() {
  ftt::config_get touchpad_device ""
}

# Is at least one *pointer* device present that is NOT our target touchpad
# and NOT in the ignore-list? Used to decide whether to warn on disable.
ftt::has_other_pointer() {
  local target ignored class id node label
  target="$(ftt::target_touchpad_id)"
  ignored="$(ftt::config_ignored_ids)"
  while IFS=$'\t' read -r class id node label; do
    [ -z "$class" ] && continue
    [ "$id" = "$target" ] && continue
    printf '%s\n' "$ignored" | grep -Fxq "$id" && continue
    # any remaining mouse OR a second touchpad counts as usable pointer input
    return 0
  done < <(ftt::devices_enumerate)
  return 1
}

# Resolve the target touchpad's current event node (id -> node), or "" .
ftt::target_touchpad_node() {
  local target class id node label
  target="$(ftt::target_touchpad_id)"
  [ -z "$target" ] && return 0
  while IFS=$'\t' read -r class id node label; do
    if [ "$class" = "touchpad" ] && [ "$id" = "$target" ]; then
      printf '%s\n' "$node"
      return 0
    fi
  done < <(ftt::devices_enumerate)
  return 0
}
