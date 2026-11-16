# Integration and provenance tests

Run both test suites from the repository root:

```sh
rtk ./tests/integration-agent-install.sh --receipt /tmp/ripwire-integration.json
rtk ./tests/test-verify-provenance.sh --receipt /tmp/verify-provenance-receipt.json
```

## 1. Agent installer integration suite (`tests/integration-agent-install.sh`)

The suite requires Ruby, `jq`, macOS `/bin/bash` 3.2, a modern Bash 5+, and the
installed Ripwire 0.6.9 payload. Paths can be supplied with `--pkgshare`,
`--bash32`, and `--modern-bash`. Missing prerequisites fail the run; no cases skip.
`--regressions-only` runs the twelve cases covering the original installer defects.

Both entrypoints run: the standalone script and the exact formula wrapper heredoc
evaluated by Ruby, preserving Ruby interpolation and shell escaping. Every run
checks the bundled installer's SHA-256 against the pinned 0.6.9 installer. Tests
copy the real payload into temporary storage, so upstream hook chmod calls cannot
touch the installed files. The installer is not mocked. This validates wrapper
behavior, not Homebrew's complete installation or upgrade transaction.

Each case has its own temporary HOME, an environment built from scratch, and a
PATH containing only required utilities plus the selected Bash. No installed
agent executable or live agent configuration participates. Explicit hook cases
register real Claude/Codex hooks in temporary JSON files; they never execute hooks.

Coverage includes default detection/fallback, all detected clients, all seven
explicit destinations, contributor inclusion/removal, manifest and symlink
contents, repeat installation, custom Antigravity detection and listing, shared
roots without Codex, explicit Claude/Codex hook registration and idempotence,
preservation of unrelated settings, and nonmutating help/list/invalid options.
Both shells run every case. Failures return nonzero and the JSON receipt records
the tested source hashes and per-case results. Temporary evidence is retained at
the receipt's `scratch` path for inspection; it contains no live user state.

## 2. Provenance verifier suite (`tests/test-verify-provenance.sh`)

Requires `jq`, `curl`, `git`, `shasum` or `sha256sum`, macOS `/bin/bash` 3.2,
and a modern Bash 5+ (`--bash32` and `--modern-bash`). Every case runs in an
isolated `HOME`, `TMPDIR`, and allowlisted `PATH` with deterministic `gh`,
`cosign`, and `brew` shims, so no network calls, `~/.sigstore` caches, or
`~/.homebrew/trust.json` writes occur.

Coverage under both shells includes:

- deterministic metadata parsing across all 17 live `Formula/*.rb` files
  (`on_macos`/`on_arm` blocks, `resource "license"` stanzas, `v`-less tags,
  `cellar: :any`, and hyphenated formula names), plus full `file:///` fixture
  verification for all 17 formulae;
- `revision`, `rebuild`, `@` (`%40`), `+` (`%2B`), and explicit `version` stanzas;
- fail-closed rejection of stale `bottle do` blocks after `autobump.sh` version bumps;
- `--save-bundles` export followed by air-gapped `--offline --bundle-dir ... --trusted-root ...`
  verification (without `curl` on `PATH`, without passing deprecated `--offline`
  to `cosign` v3, and without mutating `--bundle-dir`);
- corrupted bottle digests, `.sha256` sidecar mismatches, missing `--` Homebrew
  subjects, two-bundle split-subject substitution attacks, wrong X.509 SANs, and
  detached `.spdx.json` tampering against both `bottle-lineage/v1` and `cosign`
  DSSE predicates;
- `cosign` optional skip vs `--require-cosign`, isolated `--homebrew` (`USER`
  fallback, `XDG_CONFIG_HOME`, `GH_CONFIG_DIR` preservation, tap drift, and empty
  `brew verify` results), `scripts/update-readme-bottles.sh` (`--check` / atomic write),
  `scripts/ci/common.sh` caller-state preservation, `scripts/ci/publish-bottles.sh`
  block-aware `bottle do ... end` + `README.md` marker validation, and `set -u`
  early-exit `TMPDIR` cleanup.
