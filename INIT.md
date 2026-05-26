# INIT.md — Kickoff for `framework-touchpad-toggle`

> **This file is initialization-only. It is one of your tasks below to delete
> it (and the other init-only files) once the project is complete.** Do not
> ship it in a release.

You are finishing a Homebrew formula project, `framework-touchpad-toggle`,
that was scaffolded by a previous session. The scaffold is functional —
shellcheck-clean, shfmt-clean, smoke tests pass — but it was built against a
*reconstruction* of the `nsheaps` conventions, not the real repositories.
Your job is to reconcile it against the real repos, finish it, verify it, and
prepare it for publishing.

## Context you have that the scaffolder did not

You have access to the `nsheaps` GitHub organization. The scaffolder did not
and worked from a research report (`docs/RESEARCH-nsheaps-pattern.md`). Where
the real repos and that report disagree, **the real repos win.**

## Phase 0 — Ground yourself

1. Read `CLAUDE.md` fully.
2. Read `docs/RESEARCH-nsheaps-pattern.md` (reference only — may be slightly
   wrong; verify everything against the real repos).
3. Clone/inspect the real reference repos:
   - `nsheaps/op-exec` — the canonical "shell-script-as-a-formula" repo.
   - `nsheaps/homebrew-devsetup` — the destination tap; note the
     **meta formula pattern** and the `devsetup-configure-*` install/
     upgrade/remove contract (`--preserve` / `--force` semantics).
4. List concrete deltas between this scaffold and `op-exec`: file layout,
   `mise.toml` tasks, `.release-it.json`, `package.json`, CI workflow shape,
   `.editorconfig`, `.shellcheckrc`, linter setup, `renovate.json` preset.

## Phase 1 — Reconcile with the real conventions

5. Align `mise.toml`, `.release-it.json`, `package.json`, `.yarnrc.yml`,
   `renovate.json`, and `.github/workflows/*` with the **actual** `op-exec`
   files. Match task names, action versions, and the release pipeline exactly.
   If `op-exec`'s CI job names differ from `check`/`audit`, update both the
   workflow and `.github/settings.yml` `required_status_checks.contexts`.
6. Confirm whether `op-exec` formats with `shfmt` settings other than
   `-i 2 -ci`; if so, reformat and update `mise.toml` to match.
7. Verify the `nsheaps/renovate-config` preset name is correct.
8. Confirm the Ruby formula matches `homebrew-devsetup` conventions
   (rubocop config, `brew style`). Add a `.rubocop.yml` if the tap expects
   per-repo Ruby lint config.

## Phase 2 — Finish functionality

The scaffold is complete and working, but verify and harden these:

9. **Device identity** (`lib/devices.sh`): confirm stable per-unit IDs are
   correct on real hardware paths. The internal Framework touchpad presents
   as I²C `PIXA3854` (`phys:i2c-PIXA3854:00`); USB mice should resolve to
   `ID_PATH` + serial, falling back to port path. Each ignored / last-seen
   device must be written to the config with a human-readable `#` comment.
10. **X11 vs Wayland** (`lib/session.sh`): X11 toggles the *specific*
    configured device via `xinput`; GNOME Wayland uses
    `gsettings ... touchpad send-events` and must WARN that it cannot target
    a single device when an external touchpad is present. Offer to configure
    for whichever session is active; the config should not hard-bind to one.
11. **Notifications** (`lib/notify.sh`): `🖱️` prefix on all notifications,
    `🚨🖱️` on the no-other-mouse warning; honor `notify_timeout_ms` and the
    persistent-warning option. Confirm the warning still surfaces (stderr)
    even when notifications are disabled.
12. **Startup** (`startup` command + autostart entry): on login, if the
    touchpad is disabled and no non-ignored mouse exists, either warn
    (optionally persistent) or re-enable, per config.
13. **Shortcut install**: detects an existing assignment of the chosen
    accelerator and prompts to overwrite; records the Fn-modifier choice and
    its caveat. Verify the gsettings custom-keybinding slot logic against a
    real GNOME 46 session if possible.
14. **Formula install/link**: links the script; if a `framework-touchpad-toggle`
    already exists on PATH the install must fatal (Homebrew's link step does
    this, but confirm and make the message clear). macOS must fatal.
    Non-Framework / non-Debian must only warn.
15. Compute and fill the real `sha256` in the formula at release time (the
    placeholder is all zeros). The `url` points at the tag tarball.

## Phase 3 — Verify

16. Run `mise run check` — must be green.
17. Run `brew audit --strict --formula ./Formula/framework-touchpad-toggle.rb`
    and `brew style ...` — must be green. Expect (and confirm) the audit does
    not flag a blocking interactive-install error, because `post_install`
    is gated to be non-interactive under `NONINTERACTIVE`/no-TTY.
18. Do a real `brew install --build-from-source ./Formula/...` on a Linux
    box; then on a Framework laptop under both X11 and Wayland exercise:
    `configure`, `toggle`, `enable`, `disable`, `status`, `list-devices`,
    `startup`, `install-shortcut`, `uninstall-shortcut`, `config-path`.
19. Expand `test/smoke.sh` if you add new arg-parsing paths. Keep it
    hardware-free so it runs in CI.

## Phase 4 — Publish wiring

20. Add `Formula/framework-touchpad-toggle.rb` to the `nsheaps/homebrew-devsetup`
    tap (or wire the `bump-tap` dispatch in `.github/workflows/release.yml`
    to do it). Confirm `brew install nsheaps/devsetup/framework-touchpad-toggle`
    resolves once a release exists.
21. Ensure the `release` workflow's `TAP_DISPATCH_TOKEN` secret is documented
    in the README as a required repo secret (or remove the bump-tap job if
    the tap pulls bumps itself).

## Phase 5 — Cleanup (do this last)

22. **Delete all initialization-only files** once everything above is done:
    - `INIT.md` (this file)
    - `docs/RESEARCH-nsheaps-pattern.md` (scaffolding reference only)
    - any other scratch/handoff files not meant to ship
    Remove them with `git rm` so they are gone from the tree, and confirm
    nothing else references them.
23. Make a final pass over `README.md` so it stands on its own without the
    init docs.

## Phase 6 — Repository settings (do this absolutely last)

24. Only after the repo exists on GitHub, the code is pushed, CI is green,
    and at least one successful CI run has produced the `check` and `audit`
    status contexts: apply branch protection using the **`repository-settings`
    GitHub App** (https://github.com/repository-settings/app, install at
    https://github.com/apps/settings).
25. The desired configuration is already written to `.github/settings.yml`.
    Confirm the Settings app is installed on the repo so that file is
    applied; verify in the GitHub UI that `main` ends up protected with:
    required PR review, required status checks `check` + `audit` (strict),
    linear history, and conversation resolution required.
26. If the `nsheaps` org standardizes on GitHub-native rulesets instead of
    the Settings app, follow the org convention and translate
    `.github/settings.yml`'s `branches[].protection` into a ruleset instead.

## Definition of done

- `mise run check` and `brew audit --strict` both green in CI.
- Installs and runs on a Framework laptop under GNOME X11 **and** Wayland.
- macOS install fatals; non-Framework/non-Debian only warns.
- Interactive install works; unattended install (options/env, or
  `NONINTERACTIVE`) works with zero prompts.
- Published and installable via `nsheaps/devsetup`.
- All init-only files removed; `main` branch protection applied via the
  `repository-settings` app.
