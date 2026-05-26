---
description: Full local verification of the formula and scripts
---
Verify framework-touchpad-toggle end to end:

1. `mise run lint` — shellcheck must be clean.
2. `mise run fmt-check` — shfmt must report no diffs.
3. `mise run test` — the smoke suite must pass.
4. If Homebrew is available: `brew audit --strict --formula ./Formula/framework-touchpad-toggle.rb` and `brew style ./Formula/framework-touchpad-toggle.rb`.
5. Sanity-check the formula install logic: confirm `on_macos` fails, and that `post_install` only warns (never fatals) on non-Framework / non-Debian.
6. Report any failures with the exact command and output. Do not "fix" by loosening tests.
