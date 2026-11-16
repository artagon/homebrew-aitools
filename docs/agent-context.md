# Maintenance context

The tap maintains 23 formulae split between upstream release binaries and source
builds. Nine formulae package pinned upstream release binaries or archives:
`tgrep`, `ck`, `fff-mcp`, `agent-mail` (`mcp-agent-mail` and `am`), `br`, `bd`,
`bv`, `herdr`, and `agentsync` (`ck` and `fff-mcp` skills and agent installers are
planned in the `artagon-scripts` change `add-artagon-ck-fff-search-plugins`).
Fourteen formulae build from source: `tree-sitter-java-valhalla` (a patched
`tree-sitter-java` 0.23.5 that parses JDK 28 Valhalla `javac` syntax),
`ast-grep-valhalla` and `ripwire` (compiled against `tree-sitter-java-valhalla`),
`hashline`, `skillfile`, `skillprism`, and `squeez` (Rust), `hindsight` (Rust CLI
plus TypeScript/Node `coding-agents` stdio MCP bundle), `nats` (Go), `waza` (Go CLI
plus embedded Vite/React dashboard), `adrkit` (`bun` build targeting the `node`
runtime), `qmd` (TypeScript/Node with native `better-sqlite3`, `sqlite-vec`, and
`node-llama-cpp`), and `basic-memory` and `skillopt` (`uv` Python 3.13 builds from
source). CI builds and publishes Apple Silicon `macos-26` bottles across the tap.

`ripwire`, `hashline`, `adrkit`, `basic-memory`, `hindsight`, `qmd`, `waza`, and
`skillopt` bundle agent skills or plugins under `pkgshare`. Homebrew install,
upgrade, and uninstall must not activate agent integrations or modify live agent
configuration files. Ripwire activation is explicit through the formula-generated
`ripwire-agent-install` or `scripts/install-agent-skills.sh`. Where upstream tools
run startup update checks, telemetry, cloud routing, or unsafe defaults, Homebrew
builds and wrappers harden them (`HASHLINE_NO_UPDATE_CHECK=1`,
`AGENTSYNC_NO_UPDATE_CHECK=1`, `SKILLFILE_NO_UPDATE_NOTIFIER=1`,
`WAZA_NO_UPDATE_CHECK=1`, `BASIC_MEMORY_AUTO_UPDATE=false`,
`BASIC_MEMORY_NO_PROMOS=1`, `BASIC_MEMORY_FORCE_LOCAL=true` with HTTP/SSE/`cloud`
blocked; `hindsight` restricted to loopback `127.0.0.1`/`::1`/`localhost` with
`cloud` and `autoUpdate` disabled; `squeez` defaulting to `auto_compress_md=false`,
`persona=off`, and `wrap_bash=false`; `skillopt-sleep` defaulting to `--backend mock`
with human review before `adopt`), and formula `caveats` warn against in-place
self-updaters (`hashline update`, `am self-update`, `br upgrade`, `bv --update`,
`herdr update`, `basic-memory update`, `hindsight-coding-agents update`,
`squeez update`, `waza update`).

`agent-mail`, `br`, and `bv` use the `MIT License with OpenAI/Anthropic Rider`.
Because SPDX has no identifier for custom riders, those formulae declare
`license :cannot_represent` and install the full upstream `LICENSE` into `prefix`.

Both entrypoints support stock macOS Bash 3.2. Keep invocation arrays nonempty:
expanding an empty array under `set -u` aborts Bash 3.2. The installer path is the
first element of the argument array; optional flags are appended to it.

Codex detection uses its executable or its own configuration root. The shared
`.agents` root is a fallback destination and does not establish Codex presence.
Antigravity detection also recognizes an existing `AGY_SKILLS_DIR` directory.

The README qualifies formula names with `artagon/aitools/` because Homebrew core
also contains same-named `tgrep`, `nats`, and `herdr` formulae and differently
named formulae with overlapping binaries. Declare `conflicts_with` only when a
differently named formula installs conflicting executables: `ast-grep-valhalla`
(`ast-grep`, installing `ast-grep` and `sg`), `bd` (`beads`, installing `bd`),
`bv` (`beads_viewer`, installing `bv`), and `adrkit` (`adr-tools`, installing
`adr`). Same-named formulae across taps (`tgrep`, `nats`, `herdr`) do not declare
`conflicts_with`.

## Java grammar patch

- The patch is the `__END__` section of `Formula/tree-sitter-java-valhalla.rb`. It
  edits `grammar.js` and adds `test/corpus/valhalla.txt`. `install` regenerates
  `src/` at ABI 14 with the CLI's built-in QuickJS runtime, so Node is not needed.
- Derive new syntax from the target JDK's javac parser
  (`lib/src.zip`: `jdk.compiler/com/sun/tools/javac/parser/JavacParser.java`).
  Compile each new corpus case with that JDK and `--enable-preview` first.
- Keep the patch additive. Parse a large Java corpus with the old and new grammar;
  every file that the old grammar parses without errors must keep a byte-identical
  tree, ranges included. Run `tree-sitter test` over both corpora.
- When the patch changes, bump the `revision` of `tree-sitter-java-valhalla`,
  `ast-grep-valhalla`, and `ripwire`. The last two compile the grammar in and do
  not rebuild otherwise.
- ast-grep-valhalla swaps in the grammar crate through Cargo `[patch.crates-io]`,
  so the crate version must equal the version that ast-grep pins. Ripwire copies
  `src/parser.c` and `src/tree_sitter/*.h` over its vendored copy and patches
  `queries/java/tags.scm`. Recheck both pins when bumping either upstream.

## Version bumps

- `autobump.yml` runs `scripts/autobump.sh pr` daily. The Bash script reads
  `brew livecheck --tap artagon/aitools --newer-only --json`, rewrites each url
  that names the current version, recomputes the sha256 after it, drops any
  `revision`, and opens one pull request per formula on `bump/<formula>-<version>`.
- Pull requests opened with `GITHUB_TOKEN` start no `pull_request` run, so the
  script dispatches `tests.yml` on the bump branch with a `formulae` input: the
  bumped formula, plus `ast-grep-valhalla` and `ripwire` for a grammar bump.
- Every formula needs a `livecheck` block and a `url` with a following `sha256`
  that contains the version string. Test a rewrite offline with
  `scripts/autobump.sh rewrite FILE OLD NEW`.
- The script never updates the integration test pins. A Ripwire bump that changes
  the bundled installer or skill set fails `tests.yml` until a reviewer checks the
  payload and updates `tests/helpers/agent_install_helper.bash`.

## Bottles

- `tests.yml` runs `brew test-bot` on `macos-26` only; add a Linux entry once
  Ripwire's C++23 build is proven there, because a failed job blocks publishing.
- `tests.yml` sets each bottle's `root_url` to
  `<tap remote>/releases/download/<formula>-<pkg_version>` (`<pkg_version>` is
  `<version>` or `<version>_<revision>`). Do not pass `--root-url` or enable
  GitHub Packages. Alongside `bottles_macos-26`, `tests.yml` scans each built
  bottle tarball via `syft` (`file:<tarball>`, `+javascript-package-cataloger`)
  and uploads `provenance_macos-26` containing `.spdx.json`, `.cdx.json`, and
  `build-manifest.json` pinned to the pull request head SHA (`PR_HEAD_SHA`).
- `publish.yml` splits bottle publishing into three privilege-separated jobs
  under concurrency group `bottle-releases`:
  1. `stage-bottles` (`contents: read`, no OIDC): fetches `bottles_macos-26` and
     `provenance_macos-26` from the single passing `tests.yml` run by immutable
     artifact ID and GitHub-verified SHA-256 digest, runs
     `brew pr-pull --no-upload` and `brew bottle --merge --write`, enforces that
     only bottled `Formula/<name>.rb` files changed relative to `head_sha`, and
     uploads `publish-stage` (`commits.mbox`, `release-map.json`, bottles, SBOMs).
  2. `sign-bottles` (`.github/workflows/sign-bottles.yml`): runs with zero
     Homebrew, zero `syft`, and no repository checkout, verifies the builder
     manifest digest against the GitHub Actions API, attests SLSA v1 and
     `bottle-lineage/v1`, signs blobs and SPDX SBOMs with `cosign` v3, self-verifies
     online and air-gapped bundles, and uploads assets to **draft** GitHub Releases.
  3. `push-main`: verifies `commits.mbox` modifies only `bottle do ... end` DSL
     lines relative to `head_sha`, fast-forwards `main` (`tries: 1`), flips draft
     releases to published (or deletes unshipped drafts if the push fails), runs
     `brew verify --quiet --bottle-tag=arm64_tahoe --force --json`, and closes the pull
     request only if its `headRefOid` still equals `head_sha`.
- Publish with `gh workflow run publish.yml -f pull_request=<number> -f head_sha=<sha>`;
  GitHub dispatches only workflows that exist on `main`. A formula pull request
  merged directly ships without bottles or attestations.
- Installs need the tap trusted (`brew trust`); isolated verification jobs export
  `USER="${USER:-$(id -un)}"` (`trust/store.rb` requires `ENV.fetch("USER")`) and
  a temporary `XDG_CONFIG_HOME` while preserving `GH_CONFIG_DIR`.

## Build provenance

- Every signed bottle binds **both** filenames to the same bottle SHA-256 inside
  a single attestation statement:
  - `<formula>--<pkg_version>.<tag>.bottle[.<rebuild>].tar.gz` (`Bottle::Filename#to_s`),
    matched by `HOMEBREW_VERIFY_ATTESTATIONS=1` and `brew verify` (`attestation.rb:292`);
  - `<formula>-<pkg_version>.<tag>.bottle[.<rebuild>].tar.gz` (`Bottle::Filename#url_encode`,
    encoding `@` as `%40` and `+` as `%2B`), matched by users verifying downloaded
    GitHub Release assets directly.
  Note that `Bottle::Filename#json` omits `.rebuild` while `to_s` and `url_encode`
  include `.rebuild` when `rebuild > 0`.
- Both `publish.yml` and `attest.yml` invoke `.github/workflows/sign-bottles.yml`
  from `refs/heads/main`, so every bottle carries one canonical Fulcio X.509 SAN:
  `https://github.com/artagon/homebrew-aitools/.github/workflows/sign-bottles.yml@refs/heads/main`.
- `attest.yml` backfills or refreshes provenance sidecars (`mode: backfill`,
  `lineage_status: backfill-unverified`) for bottles already pinned in `Formula/*.rb`
  on `main` without rebuilding or overwriting existing bottle tarballs.
- Detached `.spdx.json` and `.cdx.json` sidecars are authenticated by `spdx_sha256`
  and `cdx_sha256` inside the signed `bottle-lineage/v1` attestation, and `.spdx.json`
  is additionally checked against the base64-decoded DSSE `.predicate` inside
  `.spdx.sigstore.json` (`jq -S` canonical comparison).
- SBOM fidelity depends on upstream binary metadata: Go binaries (`bd`, `bv`,
  `nats`, `tgrep`) and `cargo-auditable` Rust binaries carry full embedded module
  lists, whereas standard Rust/C/C++ binaries without embedded audit tables and
  `adrkit` (`bun build --target=node` single-file JS bundle) report archive-level
  and lockfile/package metadata visible in the bottle tarball.
- Air-gapped verification (`scripts/verify-provenance.sh --offline`) passes
  `trusted_root.jsonl` to `gh attestation verify --custom-trusted-root` and extracts
  the single-JSON Sigstore Public Good Instance `TrustedRoot` entry for
  `cosign --trusted-root` (never passing deprecated `--offline` to `cosign` v3,
  and isolating `TUF_ROOT` so `$HOME/.sigstore` is never created).

## Workflow security

- Pin every action to a full commit SHA with its tag in a comment, and verify
  that the tag resolves to that commit before changing a pin.
- Keep `permissions: {}` at the workflow level and grant each job only what it
  uses. `tests.yml` and `publish.yml`'s `stage-bottles` job run with read-only
  tokens and no `id-token` or `attestations` permissions.
- Before staging or signing, `publish.yml` snapshots `scripts/` from `main` into
  `${RUNNER_TEMP}/trusted-scripts` before applying any PR commits, and requires: a run from
  `main`; an open same-repository pull request targeting `main`; `headRefOid == head_sha` with
  `behind_by == 0`; no `.github/workflows/` or `scripts/ci/` changes unless
  `allow_workflow_changes=true` is explicitly passed after workflow review; every modified
  `Formula/*.rb` covered by `bottles_macos-26`; and a single passing `tests.yml` run whose
  `bottles_macos-26` and `provenance_macos-26` ZIP digests match GitHub's artifact metadata
  (`allow_missing_manifest=true` is an audited break-glass flag only for pre-provenance PRs).
- `publish.yml` runs `scripts/update-readme-bottles.sh` after merging `bottle do` blocks so the
  fenced `BOTTLE_PROVENANCE_TABLE` section in `README.md` stays synchronized with `Formula/*.rb`
  without creating merge conflicts on parallel bump pull requests; `push-main` validates with
  `scripts/ci/verify-patch-policy.sh` that only `bottle do ... end` DSL statements and the fenced
  `README.md` provenance table changed relative to `head_sha`.
- Multi-step CI logic lives in `scripts/ci/` (`common.sh` non-executable sourced `ci::*` library,
  `build-provenance-manifest.sh`, `stage-backfill.sh`, `sign-and-attest.sh`, `publish-bottles.sh`,
  and `verify-patch-policy.sh`) with environment-only workflow inputs and regex allowlists.
- `tests.yml` uploads bottles and provenance manifests only from a passing run
  and restores no cache, because its artifacts become release assets.
- Do not pass `token:` to setup-homebrew: it writes the token into the global
  Git config for the rest of the job. The tap is public; git-try-push takes
  its own token. Scope secrets to the steps that use them.
- Jobs that hold write tokens set `stable: true`; otherwise setup-homebrew
  runs Homebrew's `main` branch in taps.
- Never use `pull_request_target` or `workflow_run`, and never expand `${{ }}`
  inputs inside `run:`; pass them through `env` and validate them.
- `autobump.yml` has no `actions/checkout`; pushes authenticate through
  `gh auth setup-git`, so no token is stored in `.git/config`.
  `scripts/autobump.sh` rejects unexpected formula names and upstream versions.
- Lint with `actionlint` and audit with `zizmor --persona=auditor` after every
  workflow change. Note that `actionlint` 1.7.12 rejects GitHub's `$/` local
  reusable workflow syntax, so `publish.yml` and `attest.yml` use `./.github/workflows/sign-bottles.yml`
  with an inline `# zizmor: ignore[self-repository]` annotation.
- Residual risks:
  1. Homebrew's built-in `HOMEBREW_VERIFY_ATTESTATIONS=1` / `brew verify` enforces
     repository identity (`--repo artagon/homebrew-aitools`) rather than pinning a
     specific workflow SAN; `scripts/verify-provenance.sh` enforces the exact
     `sign-bottles.yml@refs/heads/main` SAN, `--source-ref refs/heads/main`,
     `--deny-self-hosted-runners`, and atomic dual-subject checks.
  2. Formulae packaging upstream prebuilt release binaries (`tgrep`, `ck`, `fff-mcp`,
     `agent-mail`, `br`, `bd`, `bv`, `herdr`, `agentsync`) attest that this tap's
     CI fetched the SHA-256-pinned upstream binary and packaged the bottle, not
     that upstream compiled the binary reproducibly from source.
  3. `tests/helpers/agent_install_helper.bash` pins Ripwire's installer SHA-256 but
     not its hook scripts.

Use [the integration suite](../tests/README.md) to validate wrapper behavior with
real payloads. An extracted Ruby-evaluated wrapper test does not prove Homebrew
installation, upgrade, permissions, or formula-test lifecycle behavior. Verify
those through actual Homebrew commands in an isolated prefix. Archive checksum
verification does not prove execution on another architecture or operating system.
