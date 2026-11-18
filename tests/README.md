# Integration and provenance tests (`bats-core`)

Repository structural checks use `ast-grep test --config sgconfig.yml` and
`ast-grep scan --config sgconfig.yml --inspect summary`. See
[ast-grep checks](../docs/ast-grep.md) for rule coverage, fixtures, and parser limits.

Run both `bats-core` 1.14+ suites (`artagon-shell/shell-testing/v1`) from the repository root:

```sh
rtk bats --tap tests/integration_agent_install.bats
rtk bats --tap tests/verify_provenance.bats
```

Override target interpreters or the Ripwire payload root with environment variables:

```sh
BATS_BASH32=/bin/bash \
BATS_MODERN_BASH=/opt/homebrew/bin/bash \
BATS_RIPWIRE_PKGSHARE=/opt/homebrew/opt/ripwire/share/ripwire \
  rtk bats --tap tests/*.bats
```

## 1. Agent installer integration suite (`tests/integration_agent_install.bats` + `tests/helpers/agent_install_helper.bash`)

Requires `bats-core`, Ruby, `jq`, a modern Bash 5+ (`BATS_MODERN_BASH`), the installed Ripwire `0.6.10` payload (`BATS_RIPWIRE_PKGSHARE`), and stock macOS `/bin/bash` 3.2 (`BATS_BASH32`) on Darwin. On macOS, missing prerequisites fail `setup_file` and zero cases skip; on Linux (where `/bin/bash` is Bash 5.x), the `(bash 3.2)` cells report explicit TAP skips while all `(bash 5+)` cells run natively against GNU userland.

Both entrypoints run across all 104 `@test` cases (`26` scenarios × `2` entrypoints × `2` target shells): the standalone `scripts/install-agent-skills.sh` script and the exact `Formula/ripwire.rb` wrapper heredoc evaluated by Ruby, preserving Ruby interpolation and shell escaping. `setup_file` verifies the bundled installer's SHA-256 against the pinned `0.6.10` digest and copies the real payload into `$BATS_FILE_TMPDIR`, so upstream hook `chmod` calls cannot touch installed Homebrew files.

Each `@test` gets an isolated `$BATS_TEST_TMPDIR` containing its own temporary `HOME`, `TMPDIR`, and allowlisted `PATH` plus the selected Bash interpreter. No installed agent executable or live agent configuration participates. Explicit hook cases register real Claude/Codex hooks in temporary JSON files and verify idempotence without executing hooks.

## 2. Provenance verifier suite (`tests/verify_provenance.bats` + `tests/helpers/provenance_helper.bash`)

Requires `bats-core`, `jq`, `curl`, `git`, `shasum` or `sha256sum`, a modern Bash 5+ (`BATS_MODERN_BASH`), and stock macOS `/bin/bash` 3.2 (`BATS_BASH32`) on Darwin (explicitly skipped on Linux where `/bin/bash` is 5.x). Every `@test` runs in an isolated `$BATS_TEST_TMPDIR` `HOME`, `TMPDIR`, and allowlisted `PATH` with deterministic `gh`, `cosign`, and `brew` shims, so no network calls, `~/.sigstore` caches, or `~/.homebrew/trust.json` writes occur.

Coverage across all 26 `@test` cases (`13` contracts × `2` target shells) includes:

- deterministic metadata parsing across all bottled `Formula/*.rb` files (`on_macos`/`on_arm` blocks, `resource "license"` stanzas, `v`-less tags, `cellar: :any`, and hyphenated formula names), plus full `file:///` fixture verification across every bottled formula;
- multi-platform (`arm64_tahoe`, `arm64_linux`, `x86_64_linux`) column-aligned `bottle do` blocks, `--all-tags` / `--bottle-tag all` / `--bottle-tag x86_64_linux` verification, multi-tag `README.md` rendering, and `ci::bottle_tag_sort_rank` ordering;
- `revision`, `rebuild`, `@` (`%40`), `+` (`%2B`), and explicit `version` stanzas;
- fail-closed rejection of stale `bottle do` blocks after `autobump.sh` version bumps;
- `--save-bundles` export followed by air-gapped `--offline --bundle-dir ... --trusted-root ...` verification (without `curl` on `PATH`, without passing deprecated `--offline` to `cosign` v3, and without mutating `--bundle-dir`);
- corrupted bottle digests, `.sha256` sidecar mismatches, missing `--` Homebrew subjects, two-bundle split-subject substitution attacks, wrong X.509 SANs, and detached `.spdx.json` tampering against both `bottle-lineage/v1` and `cosign` DSSE predicates;
- `cosign` optional skip vs `--require-cosign`, isolated `--homebrew` (`USER` fallback, `XDG_CONFIG_HOME`, `HOMEBREW_USER_CONFIG_HOME`, `GH_CONFIG_DIR` preservation, tap drift, and empty `brew verify` results), `scripts/update-readme-bottles.sh` (`--check` / atomic write), `scripts/ci/common.sh` caller-state preservation, `scripts/ci/publish-bottles.sh` block-aware `bottle do ... end` + `README.md` marker validation, and `set -u` early-exit `TMPDIR` cleanup.
