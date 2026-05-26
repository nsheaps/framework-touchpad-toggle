# framework-touchpad-toggle

Toggle the **internal touchpad** on a Framework laptop running
**Ubuntu / Debian-based Linux with GNOME** — on both X11 and Wayland.

It is a small shell tool distributed as a Homebrew formula. On install it
links the `framework-touchpad-toggle` command, collects a little
configuration, and registers a GNOME keyboard shortcut plus a login-time
check. There is **no background daemon** — it only acts when you press the
shortcut, run it manually, or log in.

## Install

```sh
brew install nsheaps/devsetup/framework-touchpad-toggle
```

Linux only. Installing on macOS fails by design (Framework laptops do not run
macOS). On non-Framework or non-Debian Linux it installs with a warning and is
considered untested.

## Usage

```sh
framework-touchpad-toggle toggle      # flip the touchpad on/off (default)
framework-touchpad-toggle enable
framework-touchpad-toggle disable
framework-touchpad-toggle status
framework-touchpad-toggle list-devices
framework-touchpad-toggle configure   # re-run configuration
framework-touchpad-toggle config-path
```

## Configuration

Configuration is collected at install time (interactively, unless run
unattended) and stored in a **version-independent** file reused across
upgrades:

```
${XDG_CONFIG_HOME:-~/.config}/framework-touchpad-toggle/config.ini
```

Collected settings: the specific touchpad device to control, the keyboard
shortcut (and whether it should require the Fn modifier), notification
on/off + duration + persistent-warning behavior, the login-time startup
check, and a list of mouse devices to ignore (for phantom/ghost devices)
when deciding whether disabling the touchpad would leave you with no pointer.

Devices are identified by a **stable per-unit ID** (not just model/vendor),
and each ID is written to the config with a human-readable `#` comment.

### Unattended install

Every value can be supplied via options/environment so install never blocks:

```sh
FTT_OPT_TOUCHPAD_DEVICE='phys:i2c-PIXA3854:00' \
FTT_OPT_KEYBINDING='<Super>F12' \
FTT_OPT_NOTIFY_ENABLED=true \
  brew install nsheaps/devsetup/framework-touchpad-toggle --with-unattended
```

`NONINTERACTIVE=1` (Homebrew's own flag) and a missing TTY also trigger
non-interactive mode.

## Development

This repo follows the `nsheaps` self-published-formula conventions
(`mise` task runner, `release-it` + Conventional Commits, `shellcheck` +
`shfmt`).

```sh
mise run check     # lint + fmt-check + test — the CI gate
mise run fmt       # auto-format shell sources
mise run release   # cut a release (release-it)
```

## License

MIT — see [LICENSE](./LICENSE).
