#!/usr/bin/env bash
# configure.sh — interactive (and option-driven) configuration, plus
# keyboard-shortcut and startup-entry installation.
#
# Config keys collected:
#   touchpad_device           stable id of the internal touchpad to control
#   keybinding                accelerator string, e.g. "<Super>F12"
#   keybinding_require_fn     true|false (document F12-rebind caveat)
#   notify_enabled            true|false
#   notify_timeout_ms         integer
#   notify_warn_persistent    true|false
#   startup_check             true|false (run `startup` at login)
#   startup_reenable_when_no_mouse  true|false
#   ignore_device=<id>        (repeatable; written with a `# comment`)
#
# Unattended install: every key can be supplied via FTT_OPT_* environment
# variables (the formula maps `--with-*` options / env to these), so when
# all values are present no prompt is shown.

# Read an option value: env override wins, else current config, else default.
# ftt::_opt <config-key> <env-name> <default>
ftt::_opt() {
  local key="$1" env="$2" def="$3" v
  v="$(printenv "$env" 2>/dev/null || true)"
  if [ -n "$v" ]; then
    printf '%s' "$v"
    return
  fi
  ftt::config_get "$key" "$def"
}

# True when every required option is supplied via env (=> fully unattended).
ftt::_fully_specified() {
  [ -n "${FTT_OPT_TOUCHPAD_DEVICE:-}" ] &&
    [ -n "${FTT_OPT_KEYBINDING:-}" ] &&
    [ -n "${FTT_OPT_NOTIFY_ENABLED:-}" ]
}

# -----------------------------------------------------------------------------
# top-level entrypoint
# -----------------------------------------------------------------------------
ftt::configure_interactive() {
  ftt::preflight
  ftt::config_init_skeleton

  local interactive=true
  if [ "${FTT_PRESERVE:-false}" = "true" ] || [ "${FTT_FORCE:-false}" = "true" ] ||
    ftt::_fully_specified; then
    interactive=false
  fi

  ftt::_configure_touchpad_device "$interactive"
  ftt::_configure_keybinding "$interactive"
  ftt::_configure_notifications "$interactive"
  ftt::_configure_startup "$interactive"
  ftt::_configure_ignore_list "$interactive"

  ftt::shortcut_install
  ftt::config_record_seen_devices "configure"

  ftt::info ""
  ftt::info "Configuration complete."
  ftt::info "Config file: $(ftt::config_file)"
  ftt::info "Edit it directly or re-run: framework-touchpad-toggle configure"
}

# -----------------------------------------------------------------------------
# 1. which touchpad to control
# -----------------------------------------------------------------------------
ftt::_configure_touchpad_device() {
  local interactive="$1" current
  current="$(ftt::_opt touchpad_device FTT_OPT_TOUCHPAD_DEVICE "")"

  if [ -n "$current" ]; then
    ftt::config_set touchpad_device "$current"
    return 0
  fi

  # auto-pick: the internal (i2c phys:) touchpad, if exactly one.
  local candidates count
  candidates="$(ftt::devices_enumerate | awk -F'\t' '$1=="touchpad"')"
  count="$(printf '%s\n' "$candidates" | grep -c . || true)"

  if [ "$count" -eq 0 ]; then
    ftt::die "no touchpad detected; cannot configure."
  fi

  if [ "$count" -eq 1 ] || [ "$interactive" != "true" ]; then
    local id label
    id="$(printf '%s\n' "$candidates" | head -n1 | cut -f2)"
    label="$(printf '%s\n' "$candidates" | head -n1 | cut -f4)"
    ftt::config_set touchpad_device "$id"
    ftt::info "Touchpad: $label"
    return 0
  fi

  ftt::info "Multiple touchpads found — choose the one to control:"
  local i=1 line
  while IFS=$'\t' read -r _ id _ label; do
    printf '  %d) %s\n' "$i" "$label"
    i=$((i + 1))
  done <<<"$candidates"
  local pick
  read -r -p "Selection [1]: " pick
  pick="${pick:-1}"
  line="$(printf '%s\n' "$candidates" | sed -n "${pick}p")"
  [ -z "$line" ] && ftt::die "invalid selection."
  ftt::config_set touchpad_device "$(printf '%s' "$line" | cut -f2)"
}

# -----------------------------------------------------------------------------
# 2. keybinding (+ fn-key caveat)
# -----------------------------------------------------------------------------
ftt::_configure_keybinding() {
  local interactive="$1" binding require_fn
  binding="$(ftt::_opt keybinding FTT_OPT_KEYBINDING "")"
  require_fn="$(ftt::_opt keybinding_require_fn FTT_OPT_KEYBINDING_REQUIRE_FN "")"

  if [ -z "$binding" ] && [ "$interactive" = "true" ]; then
    ftt::info ""
    ftt::info "Choose the key combination to toggle the touchpad."
    ftt::info "Use GTK accelerator syntax, e.g. <Super>F12, <Control><Alt>t"
    read -r -p "Key combination [<Super>F12]: " binding
    binding="${binding:-<Super>F12}"
  fi
  [ -z "$binding" ] && binding="<Super>F12"

  # If binding uses an F-key and the system is in "media-keys" mode (F-keys
  # require Fn), offer to require the Fn modifier explicitly.
  if printf '%s' "$binding" | grep -Eq 'F(1[0-2]|[1-9])'; then
    if [ -z "$require_fn" ] && [ "$interactive" = "true" ]; then
      ftt::info ""
      ftt::info "Your binding uses a function key."
      ftt::info "If your keyboard is set so the top row performs media actions"
      ftt::info "by default (and real F-keys need Fn), then this shortcut may"
      ftt::info "fire on the media action instead."
      ftt::info ""
      ftt::info "Caveat: rebinding the bare F12 key (not Fn+F12) can shadow F12"
      ftt::info "in some apps, and an accidental press may toggle the touchpad."
      if ftt::confirm "Require the Fn modifier for this shortcut?" default-no; then
        require_fn=true
      else
        require_fn=false
      fi
    fi
  fi
  [ -z "$require_fn" ] && require_fn=false

  ftt::config_set keybinding "$binding"
  ftt::config_set keybinding_require_fn "$require_fn"
}

# -----------------------------------------------------------------------------
# 3. notifications
# -----------------------------------------------------------------------------
ftt::_configure_notifications() {
  local interactive="$1" enabled timeout persistent
  enabled="$(ftt::_opt notify_enabled FTT_OPT_NOTIFY_ENABLED "")"
  timeout="$(ftt::_opt notify_timeout_ms FTT_OPT_NOTIFY_TIMEOUT_MS "")"
  persistent="$(ftt::_opt notify_warn_persistent FTT_OPT_NOTIFY_WARN_PERSISTENT "")"

  if [ -z "$enabled" ] && [ "$interactive" = "true" ]; then
    if ftt::confirm "Show a notification when the touchpad is toggled?" default-yes; then
      enabled=true
    else
      enabled=false
    fi
  fi
  [ -z "$enabled" ] && enabled=true

  if [ "$enabled" = "true" ] && [ -z "$timeout" ] && [ "$interactive" = "true" ]; then
    read -r -p "Notification duration in milliseconds [2000]: " timeout
    timeout="${timeout:-2000}"
  fi
  [ -z "$timeout" ] && timeout=2000

  if [ -z "$persistent" ] && [ "$interactive" = "true" ]; then
    ftt::info ""
    ftt::info "If the touchpad is disabled and no other mouse is connected,"
    ftt::info "pointer input is lost. This warning can stay on screen until"
    ftt::info "you dismiss it (or re-enable the touchpad)."
    if ftt::confirm "Make the no-mouse warning persistent?" default-no; then
      persistent=true
    else
      persistent=false
    fi
  fi
  [ -z "$persistent" ] && persistent=false

  ftt::config_set notify_enabled "$enabled"
  ftt::config_set notify_timeout_ms "$timeout"
  ftt::config_set notify_warn_persistent "$persistent"
}

# -----------------------------------------------------------------------------
# 4. startup behavior
# -----------------------------------------------------------------------------
ftt::_configure_startup() {
  local interactive="$1" startup reenable
  startup="$(ftt::_opt startup_check FTT_OPT_STARTUP_CHECK "")"
  reenable="$(ftt::_opt startup_reenable_when_no_mouse FTT_OPT_STARTUP_REENABLE "")"

  if [ -z "$startup" ] && [ "$interactive" = "true" ]; then
    ftt::info ""
    ftt::info "At login, the tool can check whether the touchpad was left"
    ftt::info "disabled with no other mouse attached (e.g. powered off while a"
    ftt::info "mouse was connected) and warn — or re-enable it automatically."
    if ftt::confirm "Run the startup check at login?" default-yes; then
      startup=true
    else
      startup=false
    fi
  fi
  [ -z "$startup" ] && startup=true

  if [ "$startup" = "true" ] && [ -z "$reenable" ] && [ "$interactive" = "true" ]; then
    if ftt::confirm "Auto re-enable at login when no other mouse is found?" default-no; then
      reenable=true
    else
      reenable=false
    fi
  fi
  [ -z "$reenable" ] && reenable=false

  ftt::config_set startup_check "$startup"
  ftt::config_set startup_reenable_when_no_mouse "$reenable"
}

# -----------------------------------------------------------------------------
# 5. ignore-list (ghost devices)
# -----------------------------------------------------------------------------
ftt::_configure_ignore_list() {
  local interactive="$1"

  # env-driven (unattended): comma-separated stable ids.
  if [ -n "${FTT_OPT_IGNORE_DEVICES:-}" ]; then
    local IFS=','
    for id in $FTT_OPT_IGNORE_DEVICES; do
      [ -z "$id" ] && continue
      ftt::config_add_ignored "$id" "added via FTT_OPT_IGNORE_DEVICES"
    done
    return 0
  fi

  [ "$interactive" = "true" ] || return 0

  ftt::info ""
  ftt::info "Some systems report phantom/ghost mouse devices. Any device you"
  ftt::info "ignore here will NOT count as 'another mouse' when deciding"
  ftt::info "whether to warn that pointer input is lost."
  ftt::info ""
  ftt::info "Mouse devices currently detected:"

  local mice i=1
  mice="$(ftt::devices_enumerate | awk -F'\t' '$1=="mouse"')"
  if [ -z "$mice" ]; then
    ftt::info "  (none)"
    return 0
  fi
  while IFS=$'\t' read -r _ id _ label; do
    printf '  %d) %s\n' "$i" "$label"
    i=$((i + 1))
  done <<<"$mice"

  local picks
  read -r -p "Numbers to ignore (comma-separated, blank for none): " picks
  [ -z "$picks" ] && return 0
  local IFS=','
  for p in $picks; do
    p="$(printf '%s' "$p" | tr -d '[:space:]')"
    [ -z "$p" ] && continue
    local line id label
    line="$(printf '%s\n' "$mice" | sed -n "${p}p")"
    [ -z "$line" ] && continue
    id="$(printf '%s' "$line" | cut -f2)"
    label="$(printf '%s' "$line" | cut -f4)"
    ftt::config_add_ignored "$id" "$label"
  done
}

# -----------------------------------------------------------------------------
# record all touchpad+mouse devices seen now (called on every state event)
# -----------------------------------------------------------------------------
ftt::config_record_seen_devices() {
  local event="$1"
  ftt::devices_enumerate |
    awk -F'\t' '{print $2 "\t" $4}' |
    ftt::config_write_seen_block "$event"
}

# -----------------------------------------------------------------------------
# keyboard shortcut + startup entry
# -----------------------------------------------------------------------------
# GNOME custom keybinding via gsettings. We pick a dedicated slot path so we
# can detect prior assignment and offer to overwrite.
FTT_GSETTINGS_KB_BASE="org.gnome.settings-daemon.plugins.media-keys"
FTT_KB_SLOT="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/framework-touchpad-toggle/"

ftt::shortcut_install() {
  ftt::is_gnome || {
    ftt::warn "not a GNOME session; skipping shortcut registration."
    ftt::warn "bind this command manually: framework-touchpad-toggle toggle"
    return 0
  }
  ftt::have gsettings || ftt::die "gsettings not found."

  local binding require_fn cmd
  binding="$(ftt::config_get keybinding '<Super>F12')"
  require_fn="$(ftt::config_get keybinding_require_fn false)"
  cmd="$(command -v framework-touchpad-toggle || echo framework-touchpad-toggle) toggle"

  # If require_fn is set we leave the accelerator as-is (the user enables
  # "function keys" mode at the OS level); we only document it. GNOME has no
  # accelerator token for Fn, so this is recorded for transparency.
  [ "$require_fn" = "true" ] &&
    ftt::info "Note: 'require Fn' recorded; ensure your F-row is in F-key mode."

  # detect an existing assignment of the same accelerator elsewhere
  local existing
  existing="$(ftt::_find_conflicting_binding "$binding")"
  if [ -n "$existing" ] && [ "$existing" != "$FTT_KB_SLOT" ]; then
    if ftt::confirm "Key '$binding' is already assigned ($existing). Overwrite?" default-no; then
      :
    else
      ftt::warn "keeping existing binding; touchpad shortcut NOT registered."
      return 0
    fi
  fi

  # register our slot
  local list
  list="$(gsettings get "$FTT_GSETTINGS_KB_BASE" custom-keybindings 2>/dev/null || echo "@as []")"
  case "$list" in
    *"$FTT_KB_SLOT"*) : ;;
    *)
      if [ "$list" = "@as []" ] || [ "$list" = "[]" ]; then
        gsettings set "$FTT_GSETTINGS_KB_BASE" custom-keybindings "['$FTT_KB_SLOT']"
      else
        gsettings set "$FTT_GSETTINGS_KB_BASE" custom-keybindings \
          "${list%]}, '$FTT_KB_SLOT']"
      fi
      ;;
  esac

  local schema="${FTT_GSETTINGS_KB_BASE}.custom-keybinding:${FTT_KB_SLOT}"
  gsettings set "$schema" name "Framework Touchpad Toggle"
  gsettings set "$schema" command "$cmd"
  gsettings set "$schema" binding "$binding"
  ftt::info "Keyboard shortcut registered: $binding -> $cmd"

  ftt::_startup_entry_install
}

ftt::_find_conflicting_binding() {
  local target="$1" list slot schema b
  list="$(gsettings get "$FTT_GSETTINGS_KB_BASE" custom-keybindings 2>/dev/null || echo "")"
  printf '%s' "$list" | grep -Eo "/[^']*custom-keybindings/[^']*/" | while read -r slot; do
    schema="${FTT_GSETTINGS_KB_BASE}.custom-keybinding:${slot}"
    b="$(gsettings get "$schema" binding 2>/dev/null | tr -d "'\"")"
    [ "$b" = "$target" ] && printf '%s' "$slot"
  done
}

# A freedesktop autostart entry that runs the login-time `startup` check.
ftt::_startup_entry_install() {
  [ "$(ftt::config_get startup_check true)" = "true" ] || return 0
  local dir file cmd
  dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
  file="$dir/framework-touchpad-toggle.desktop"
  cmd="$(command -v framework-touchpad-toggle || echo framework-touchpad-toggle) startup"
  mkdir -p "$dir"
  cat >"$file" <<EOF
[Desktop Entry]
Type=Application
Name=Framework Touchpad Toggle (startup check)
Comment=Warn or re-enable if the touchpad was left disabled with no mouse
Exec=$cmd
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
  ftt::info "Startup check installed: $file"
}

ftt::shortcut_uninstall() {
  if ftt::is_gnome && ftt::have gsettings; then
    local list new
    list="$(gsettings get "$FTT_GSETTINGS_KB_BASE" custom-keybindings 2>/dev/null || echo "")"
    if printf '%s' "$list" | grep -q "$FTT_KB_SLOT"; then
      new="$(printf '%s' "$list" | sed -E "s/'[^']*framework-touchpad-toggle[^']*',? ?//g")"
      [ -z "$new" ] && new="@as []"
      gsettings set "$FTT_GSETTINGS_KB_BASE" custom-keybindings "$new"
      ftt::info "Keyboard shortcut removed."
    fi
  fi
  local file="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/framework-touchpad-toggle.desktop"
  [ -f "$file" ] && {
    rm -f "$file"
    ftt::info "Startup entry removed."
  }
}
