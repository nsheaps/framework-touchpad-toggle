# Research reference — nsheaps homebrew/formula pattern

> **Initialization-only.** This is the research report the scaffolding
> session used to approximate the nsheaps conventions. It may be slightly
> inaccurate — the real `nsheaps/op-exec` and `nsheaps/homebrew-devsetup`
> repositories are authoritative. INIT.md instructs the finishing agent to
> verify against the real repos and then delete this file.

See the conversation artifact "Replicating the nsheaps Homebrew Tap Pattern"
for the full report. Key points the scaffold relied on:

- op-exec layout: `.github/`, `Formula/`, `bin/`, plus `mise.toml`,
  `package.json`, `.release-it.json`, `.shellcheckrc`, `.editorconfig`,
  `.yarnrc.yml`, `renovate.json`, `CHANGELOG.md`, `LICENSE`, `README.md`,
  `yarn.lock`.
- Versioning: release-it + @release-it/conventional-changelog, tag `v${version}`,
  GitHub release auto-generated, `npm: false`.
- mise is the task runner; `mise run check` (depends on lint, fmt-check,
  test) is the single CI gate.
- Shell: shellcheck + shfmt. Formulas: rubocop / `brew style` in the tap.
- op-exec is published INTO the `nsheaps/devsetup` tap
  (`brew install nsheaps/devsetup/op-exec`), repo `nsheaps/homebrew-devsetup`.
- homebrew-devsetup documents a meta-formula pattern (`devsetup add` /
  `devsetup alias`) and a `--preserve` / `--force` install contract for its
  `devsetup-configure-*` formulas.
- Branch protection via the `repository-settings` GitHub App and
  `.github/settings.yml`.

VERIFY ALL OF THE ABOVE against the real repositories before relying on it.
