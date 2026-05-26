# CLAUDE.md

Project memory for `framework-touchpad-toggle`. Read this first.

## What this is

A Homebrew formula + shell tool that toggles the **internal touchpad** on a
Framework laptop running **Ubuntu/Debian + GNOME** (X11 or Wayland). It is
published into the existing **`nsheaps/devsetup` tap** (repo
`nsheaps/homebrew-devsetup`), exactly like `nsheaps/op-exec`. End users run:

```
brew install nsheaps/devsetup/framework-touchpad-toggle
```

## Architecture

- `bin/framework-touchpad-toggle` — runtime entrypoint + CLI/arg parsing.
- `lib/*.sh` — sourced helpers: `common` (logging/guards), `config`
  (version-independent INI config, comment-preserving), `devices`
  (enumeration + stable per-unit IDs), `session` (X11/Wayland detect +
  per-device enable/disable), `notify` (desktop notifications, emoji),
  `configure` (interactive + option-driven setup, shortcut install).
- `Formula/framework-touchpad-toggle.rb` — the Homebrew formula. Installs
  `lib/*` under `libexec`, writes a thin wrapper into `bin`.
- `share/` — reference `.desktop` and systemd-user unit.
- `test/smoke.sh` — hardware-free CLI smoke tests; the CI `test` task.

## Conventions (match nsheaps/op-exec exactly)

- **mise** is the task runner. `mise run check` (lint + fmt-check + test) is
  the single CI gate. Never invent a different gate.
- **release-it** + Conventional Commits for versioning. Tag format `v${version}`.
  Never hand-edit `CHANGELOG.md` or hand-create tags.
- **Conventional commit types only:** feat, fix, perf, refactor, docs, chore.
- Shell is linted with **shellcheck** and formatted with **shfmt -i 2 -ci**.
- Formulas are checked with **brew audit --strict** and **brew style**.

## Hard rules

- **Linux-only.** macOS must fatal (`on_macos`/`OS.mac?` → `odie`). Framework
  laptops do not run macOS, so this can never be a real install target.
- **Non-Framework / non-Debian:** WARN, never fatal, in the formula
  (`post_install` uses `opoo`). The runtime script fails hard only when the
  tool is actually *invoked* on an unsupported config.
- **The interactive install is intentional and against Homebrew best
  practice.** It MUST be skippable: `post_install` runs `configure --preserve`
  whenever `NONINTERACTIVE` is set, there is no TTY, or `--with-unattended`
  is passed. Do not "fix" this by removing the prompts. Do NOT submit this
  formula to homebrew-core.
- **Config is version-independent** (`~/.config/framework-touchpad-toggle/
  config.ini`) and reused across upgrades. Never write config into the
  Homebrew cellar/prefix.
- **Device identity must be per-unit**, not model/vendor — see `lib/devices.sh`.
  Stable IDs carry an auto-written human-readable `#` comment in the config.
- Do not `git push` or force-push. Do not weaken tests to make them pass.

## Before committing

Run `mise run check`. It must pass. Then `brew audit --strict` if Homebrew
is present.
