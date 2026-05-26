---
description: Cut a new release using release-it (conventional commits)
---
Run a release of framework-touchpad-toggle.

Steps:
1. Ensure the working tree is clean and you are on `main`.
2. Run `mise run check` and confirm it passes.
3. Review commits since the last tag (`git log $(git describe --tags --abbrev=0)..HEAD --oneline`) and confirm the conventional-commit types are correct — the changelog and the version bump derive from them.
4. Run `mise run release` (wraps `release-it`). For a forced increment use `yarn dlx release-it <patch|minor|major>`.
5. Confirm the new tag `v<version>` and the GitHub release were created.
6. Remember the Homebrew formula in the `nsheaps/homebrew-devsetup` tap must be bumped (url + sha256). The `release` workflow dispatches this automatically if `TAP_DISPATCH_TOKEN` is configured; otherwise open that PR manually.

Never edit `CHANGELOG.md` by hand — it is generated.
