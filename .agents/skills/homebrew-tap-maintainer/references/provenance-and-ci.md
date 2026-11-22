# Bottle Publishing, Provenance, and CI Reference

Reference marker: `artagon-aitools/provenance-and-ci/v1`.

## Publishing Flow (Never Direct-Merge Formula PRs)

1. Open a pull request targeting `main`. `.github/workflows/tests.yml` gates `test-bot` on `lint` (`ubuntu-24.04`) and defaults pull requests and `autobump.yml` dispatches to Linux-only builders (`ubuntu-24.04` for `x86_64_linux`, `ubuntu-24.04-arm` for `arm64_linux`). Once Linux CI passes on the reviewed head, opt into `macos-26` (`arm64_tahoe`) bottles once by applying the `build-macos-bottles` PR label or dispatching `gh workflow run tests.yml --ref <branch> -f include_macos=true` (`publish-bottles.sh` automatically ignores inert `action_required` and unrelated-label `skipped` runs).
2. Ensure the PR branch has `behind_by == 0` relative to `main` (`publish.yml` refuses out-of-date branches).
3. Dispatch `publish.yml` from `main`:
   ```sh
   gh workflow run publish.yml -f pull_request=<number> \
     -f head_sha="$(gh pr view <number> --json headRefOid --jq .headRefOid)"
   ```
   Pass `-f allow_workflow_changes=true` only after reviewing `.github/workflows/` or `scripts/ci/` diffs.

## Security Invariants

- **Trusted script snapshot**: `publish.yml` copies `scripts/` from `refs/heads/main` to `${RUNNER_TEMP}/trusted-scripts` before `brew pr-pull` or `git am`. Note that `update-readme-bottles.sh` runs `main`'s `verify-provenance.sh`, so a new URL tag convention needs parser support on `main` (or an explicit `version` stanza) before publishing.
- **Sole OIDC signer**: Only `.github/workflows/sign-bottles.yml@refs/heads/main` holds `id-token: write` and `attestations: write`. It executes zero untrusted build/formula code and binds **both** `<formula>--<pkg_ver>.<tag>.bottle[.<rebuild>].tar.gz` (`Bottle::Filename#to_s`, verified by `brew verify`) and `<formula>-<pkg_ver>.<tag>.bottle[.<rebuild>].tar.gz` (`Bottle::Filename#url_encode`, GitHub Release asset) in a single SLSA v1 statement and a single `bottle-lineage/v1` statement.
- **Patch policy**: `scripts/ci/verify-patch-policy.sh` enforces that commits staged on top of `head_sha` modify only `bottle do ... end` statements in `Formula/*.rb` and the fenced `<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->` ... `<!-- END BOTTLE_PROVENANCE_TABLE -->` block in `README.md`. Keep those two HTML comment markers on standalone lines in `README.md` and never quote them inline elsewhere in `README.md`.
