# Maintenance context

Live formula definitions, upstream versions, and bottle digests live in
[`Formula/*.rb`](../Formula) and [`README.md`](../README.md). Keep maintenance
documentation focused on tap-wide invariants rather than per-formula counts or
version numbers so parallel formula pull requests do not conflict.

## Formula architecture & hardening

- **Source builds vs. pinned archives**: Prefer reproducible source builds
  (`cargo install --locked`, `std_go_args`, `uv`, `pnpm`/`bun`/`npm`, `cmake`).
  When packaging prebuilt upstream release archives or bare binaries, pin exact
  per-platform SHA-256 checksums and run `chmod 0755` on bare binaries staged
  into `libexec/` (Homebrew's `Cleaner` fixes executable permissions only in
  `bin/`, `sbin/`, and `lib/`, never `libexec/`). CI builds and publishes
  `arm64_tahoe`, `arm64_linux`, and `x86_64_linux` bottles.
- **Passive `pkgshare` staging & zero live dotfile mutation**: Stage bundled
  `SKILL.md` files, plugins, hooks, guides, and configuration templates under
  `pkgshare`. `brew install`, `brew upgrade`, and `brew uninstall` must never
  activate agent integrations or edit user dotfiles (`~/.claude*`, `~/.codex*`,
  `~/.gemini*`, `~/.config/*`, `~/.hammerspoon`, shell profiles,
  `~/.homebrew/trust.json`, or `~/.sigstore`). Activation happens only through
  explicit user-invoked commands (such as `ripwire-agent-install` or
  `scripts/install-agent-skills.sh`). Cask `postflight_steps` write only the
  cask app's own `UserDefaults` and guarded single-UTI LaunchServices defaults
  (opt-out via `HOMEBREW_*_SKIP_DEFAULTS=1`).
- **Build & runtime wrapper defaults**: Where upstream tools perform startup
  version checks, telemetry/analytics beacons, unsolicited model/price downloads,
  remote cloud routing, or implicit paid API-key billing, disable them at build
  time and in `/bin/bash` 3.2+ wrappers (`set -euo pipefail`, terminating flag
  scans at `--`). Default local servers and collectors to loopback (`127.0.0.1`),
  block in-place self-updaters (`exit 2`), and document
  `brew upgrade artagon/aitools/<formula>` in `caveats`.
- **Cross-platform Python & Node packaging**: In `uv` formulae (`python@3.13` on
  Linux, managed `3.13` on macOS), pass `--python <python_arg>` and a fixed
  `--exclude-newer <RFC3339>` cutoff to `uv build` and `uv tool install`, delete
  upstream `.python-version`, `direct_url.json`, and `uv-receipt.toml` files,
  prune foreign-OS/CPU prebuilt libraries (`prebuilds/*`,
  `pydevd_attach_to_process/*`), normalize macOS wheel `.dylib` IDs to `@rpath/`
  with `preserve_rpath`, and add Linux `patchelf` + `zlib-ng-compat` only when a
  bundled shared object links `libz.so.1`.
- **Licenses**: Declare standard SPDX identifiers where valid. When an upstream
  license adds a custom non-SPDX rider, declare `license :cannot_represent` and
  install the full upstream `LICENSE` (plus any required notice files) into
  `prefix`.
- **Qualification & `conflicts_with`**: Always qualify installation examples
  with `artagon/aitools/<formula>` so Homebrew selects this tap over same-named
  core formulae. Declare `conflicts_with` only when a differently named formula
  installs overlapping executables, never on same-named formulae across taps.
- **Bash 3.2 installer & CLI detection**: Keep invocation arrays nonempty before
  expansion (empty `"${arr[@]}"` aborts stock macOS `/bin/bash` 3.2 under
  `set -u`). Detect coding-agent CLIs from their own executable or dedicated
  config root; shared `.agents` roots are fallback destinations rather than proof
  of a specific CLI, while `AGY_SKILLS_DIR` also establishes Antigravity presence.

## Cask hardening & install flags

- **Cask DSL layout, qualification, & delivery**: `Casks/*.rb` follow idiomatic
  Homebrew Cask stanza order (`version`, `sha256`, `url` using `#{version}`,
  `name`, `desc`, `homepage`, `livecheck`) enforced by `brew style`. Unlike
  `Formula/*.rb`, casks do not build bottles, are not rewritten by
  `scripts/autobump.sh` (`--formula` only), and cannot be published through
  `publish.yml` (`brew pr-pull` requires `Formula/*.rb` bottle artifacts);
  review and merge cask-only pull requests directly after style, audit, and Bats
  checks pass. Qualify install and upgrade examples in `caveats` with
  `brew install --cask artagon/aitools/<cask>` and
  `brew upgrade --cask artagon/aitools/<cask>`, and declare
  `conflicts_with cask:` only for differently named casks (never for same-named
  casks in `homebrew/cask`).
- **Sandboxed Homebrew 5.x `postflight_steps`**: Always use `postflight_steps`
  (never deprecated `postflight`) with `run "/bin/bash"`,
  `args: ["-euo", "pipefail", "-c", <<~'SH', ...]`, `writable_base: :home`,
  minimal explicit `writable_paths`, and `must_succeed: false`. Homebrew 5.x
  executes `postflight_steps` inside a macOS Seatbelt sandbox with network
  access disabled and home writes limited to declared `writable_paths`: declare
  `["Library/Preferences"]` for unsandboxed apps, and add
  `"Library/Containers/<bundle-id>/Data/Library/Preferences"` for App Sandbox
  apps. Pass template tokens such as `"{{HOMEBREW_PREFIX}}"` as positional
  arguments (`"_", "{{HOMEBREW_PREFIX}}"`) rather than interpolating them into
  double-quoted shell code. Keep inline `<<~'SH'` scripts compatible with stock
  macOS `/bin/bash` 3.2, check each `/usr/bin/defaults write` independently via
  a status-tracking helper (`rc=0`, `exit "${rc}"`) so one failing write does
  not abort remaining hardening writes under `set -e`, and emit warnings on
  stderr.
- **Scoped preference writes vs. user dotfiles**: Cask `postflight_steps` may
  write only the cask app's own `UserDefaults` domain (and, where applicable,
  one guarded LaunchServices default handler). Installing or upgrading a cask
  must never modify `~/.config/*`, `~/.hammerspoon`, coding-agent configs
  (`~/.claude*`, `~/.codex*`, `~/.gemini*`), shell profiles,
  `~/.homebrew/trust.json`, or `~/.sigstore`; reserve user-config cleanup
  strictly for `zap trash:` (`brew uninstall --zap`).
- **Upgrade ownership & Sparkle/telemetry defaults**: Omit `auto_updates true`
  whenever the tap disables Sparkle or in-app auto-updates by default so
  `brew upgrade` does not skip the cask without `--greedy`. In
  `postflight_steps`, disable Sparkle automatic checks and profile reporting by
  default via `/usr/bin/defaults write <bundle-id>`:
  - `SUEnableAutomaticChecks -bool false`
  - `SUAutomaticallyUpdate -bool false`
  - `SUSendProfileInfo -bool false`
  - `SUHasLaunchedBefore -bool true` (suppresses Sparkle's first-launch update
    prompt).
  When auto-updates are explicitly opted back in, write
  `SUEnableAutomaticChecks -bool true`. Disable app-specific usage analytics and
  crash reporting defaults by default as well, re-enabling them only when the
  telemetry override flag is truthy.
- **`HOMEBREW_*` install-time environment flags**: Expose all install-time
  overrides exclusively via `HOMEBREW_*` variables because `brew` filters out
  non-`HOMEBREW_*` environment variables before executing cask stanzas. Resolve
  flags with a Bash 3.2 `env_bool` helper where per-cask
  `HOMEBREW_<CASK>_<FLAG>` (token uppercased with hyphens replaced by
  underscores) takes precedence over tap-wide `HOMEBREW_AITOOLS_<FLAG>`, falling
  back to the cask default. Trim leading and trailing whitespace so blank
  per-cask values fall back to tap-wide values, and use a **fail-closed**
  allowlist: accept only case-insensitive `1`/`true`/`yes`/`on` as truthy and
  `0`/`false`/`no`/`off` as falsy; on any unrecognized value, warn on stderr and
  fail closed (`false`). Standard flag families (documented in each
  cask's `caveats`):
  - `SKIP_DEFAULTS` (default `0`): exit `0` immediately with zero `defaults` or
    `duti` writes.
  - `AUTO_UPDATES` (default `0`): keep `SUEnableAutomaticChecks -bool true`.
  - `TELEMETRY` (default `0`): keep app usage analytics and crash reporting
    enabled (for casks with app-level telemetry keys).
  - `SET_DEFAULT` (default `1`, or `0` when `CI` is truthy): control
    LaunchServices default-handler registration (for casks that register a
    default handler).
- **LaunchServices default-handler registration (`duti`)**: Declare
  `depends_on formula: "duti"`, resolve an executable file (`[ -f ] && [ -x ]`)
  from `"${homebrew_prefix}/bin/duti"` first before falling back to
  `"/opt/homebrew/bin/duti"` and `"/usr/local/bin/duti"`, probe at most **one**
  canonical UTI, trim whitespace from `duti -d <uti>`, skip `duti -s` when exit
  status is `0` and output matches the bundle ID, run `duti -s` only on exit
  status `0` or `1`, and warn without calling `duti -s` on exit status `>= 2`.
  Never loop or batch `duti -s` across multiple UTIs or file extensions (macOS
  15+ displays one modal `CoreServicesUIAgent` confirmation dialog per handler
  change). Skip registration whenever `CI` is truthy unless
  `HOMEBREW_<CASK>_SET_DEFAULT=1` (or `HOMEBREW_AITOOLS_SET_DEFAULT=1`)
  explicitly overrides it.
- **Cask verification**: Because `ast-grep` and `shellcheck` do not parse Bash
  inside Ruby `<<~'SH'` heredocs, validate cask changes with
  `brew style Casks/<name>.rb`,
  `brew audit --cask --strict --online artagon/aitools/<name>`,
  `brew livecheck --cask artagon/aitools/<name>`, and
  `bats --tap tests/cask_postflight_defaults.bats` across `/bin/bash` 3.2 and
  Bash 5+ (extracting each cask's inline script against stubbed `defaults` and
  `duti` binaries in `$BATS_TEST_TMPDIR`).

## Java grammar patch

- The patch is the `__END__` section of `Formula/tree-sitter-java-valhalla.rb`. It
  edits `grammar.js` and adds `test/corpus/valhalla.txt`. `install` regenerates
  `src/` at ABI 14 with the CLI's built-in QuickJS runtime, so Node is not needed.
- Derive new syntax from the target JDK's `javac` parser
  (`lib/src.zip`: `jdk.compiler/com/sun/tools/javac/parser/JavacParser.java`).
  Compile each new corpus case with that JDK and `--enable-preview` first.
- Keep the patch additive. Parse a large Java corpus with the old and new grammar;
  every file that the old grammar parses without errors must keep a byte-identical
  tree, ranges included. Run `tree-sitter test` over both corpora.
- When the patch changes, bump the `revision` of `tree-sitter-java-valhalla` and
  every formula that compiles its patched grammar in (`ast-grep-valhalla`,
  `ripwire`).
- `ast-grep-valhalla` swaps in the grammar crate through Cargo `[patch.crates-io]`,
  so the crate version must equal the version that `ast-grep` pins. `ripwire` copies
  `src/parser.c` and `src/tree_sitter/*.h` over its vendored copy and patches
  `queries/java/tags.scm`. Recheck both pins when bumping either upstream.

## Version bumps

- `autobump.yml` runs `scripts/autobump.sh pr` daily. The Bash script reads
  `brew livecheck --formula --json --quiet --newer-only` (formulae only, not
  casks), rewrites each `url`
  that names the current version, recomputes the `sha256` after it (updating an
  intervening `version` line when present), drops any `revision`, and opens one
  pull request per formula on `bump/<formula>-<version>`.
- Pull requests opened with `GITHUB_TOKEN` sit in `action_required` without
  executing `pull_request` jobs, so `scripts/autobump.sh` dispatches `tests.yml`
  on the bump branch (ignoring inert `action_required` runs) with a `formulae`
  input naming the bumped formula and any compile-time dependents.
- Every formula needs a `livecheck` block and a literal-versioned `url` with an
  immediately following 64-hex `sha256`. Test a rewrite offline with
  `scripts/autobump.sh rewrite FILE OLD NEW`.
- `autobump.sh` never updates integration test SHA-256 pins. An upstream bump that
  changes a pinned installer or skill payload fails `tests.yml` until a reviewer
  inspects the diff and updates `tests/helpers/agent_install_helper.bash`.

## Bottles

- `tests.yml` gates `test-bot` on `lint` (`ubuntu-24.04`, which also runs
  `tests/verify_provenance.bats`, `tests/ci_workflow_plan.bats`, and
  `tests/cask_postflight_defaults.bats` with zero macOS runners) and defaults
  pull requests and `autobump.yml` dispatches to Linux bottle builders
  (`ubuntu-24.04` for `x86_64_linux`, `ubuntu-24.04-arm` for `arm64_linux`),
  failing immediately if `skipped_or_failed_formulae` is non-empty. Opt into
  `macos-26` (`arm64_tahoe`) bottle builds once on the reviewed head via
  `gh workflow run tests.yml --ref <branch> -f include_macos=true` or by
  applying the `build-macos-bottles` PR label before running `publish.yml`.
  Ubuntu 24.04 LTS supplies `glibc 2.39` directly on hosted runners without
  `--privileged` containers. `attest.yml`'s `verify-homebrew` job likewise runs
  on `ubuntu-24.04`.
- `tests.yml` sets each bottle's `root_url` to
  `<tap remote>/releases/download/<formula>-<pkg_version>` (`<pkg_version>` is
  `<version>` or `<version>_<revision>`). Do not pass `--root-url` or enable
  GitHub Packages. Alongside `bottles_<os>`, `tests.yml` scans each built
  bottle tarball via `syft` (`file:<tarball>`, `+javascript-package-cataloger`)
  and uploads `provenance_<os>` containing `.spdx.json`, `.cdx.json`, and
  `build-manifest.json` pinned to the pull request head SHA (`PR_HEAD_SHA`).
- `publish.yml` splits bottle publishing into three privilege-separated jobs
  under concurrency group `bottle-releases`:
  1. `stage-bottles` (`contents: read`, no OIDC): selects the newest non-inert
     `tests.yml` run for `head_sha`, fetches `bottles_<os>` and `provenance_<os>`
     by immutable artifact ID and GitHub-verified SHA-256 digest, runs
     `brew pr-pull --no-upload` (`--workflows=publish.yml --ignore-missing-artifacts=publish.yml`)
     and `brew bottle --merge --write --no-all-checks` in `FormulaAudit::BottleOrder`
     (`arm64_tahoe`, `arm64_linux`, `x86_64_linux`), enforces that every changed
     `Formula/<name>.rb` produced all three bottle tags, and uploads `publish-stage`
     (`commits.mbox`, `release-map.json`, bottles, SBOMs).
  2. `sign-bottles` (`.github/workflows/sign-bottles.yml`): runs with zero
     Homebrew, zero `syft`, and checks out only trusted `refs/heads/main`, verifies
     each builder `provenance_<os>` digest against the GitHub Actions API, attests
     SLSA v1 and `bottle-lineage/v1`, signs blobs and SPDX SBOMs with `cosign` v3,
     self-verifies online and air-gapped bundles (`--digest` for `>128 MiB` blobs),
     and uploads assets to **draft** GitHub Releases.
  3. `push-main`: verifies `commits.mbox` SHA-256 and enforces that diffs relative
     to `head_sha` touch only `bottle do ... end` DSL lines matching `release-map.json`
     (and the fenced `README.md` `BOTTLE_PROVENANCE_TABLE`), fast-forwards `main`
     (`tries: 1`), flips draft releases to published (or deletes run-created drafts
     if pushing fails), runs `brew verify --quiet --bottle-tag=<tag> --force --json`
     for every published `(formula, tag)` pair, and closes the pull request only if
     its `headRefOid` still equals `head_sha`.
- Publish with `gh workflow run publish.yml -f pull_request=<number> -f head_sha=<sha>`;
  GitHub dispatches only workflows that exist on `main`. Merging a formula pull
  request directly skips bottle publishing and leaves `Formula/*.rb` unbottled.
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
- SBOM fidelity depends on upstream binary metadata: Go binaries and
  `cargo-auditable` Rust binaries carry full embedded module lists, whereas
  compiled C/C++/Rust binaries without audit tables and single-file JS bundles
  report archive-level and package/lockfile metadata visible in the bottle tarball.
- Air-gapped verification (`scripts/verify-provenance.sh --offline`) requires an
  explicit `--trusted-root` outside `--bundle-dir`, passes `trusted_root.jsonl` to
  `gh attestation verify --custom-trusted-root`, and extracts the Sigstore Public
  Good Instance `TrustedRoot` entry for `cosign --trusted-root` (never passing
  deprecated `--offline` to `cosign` v3, and isolating `TUF_ROOT` so `$HOME/.sigstore`
  is never created).

## Workflow security

- Pin every external action to a full 40-hex commit SHA with its tag in a comment,
  and verify that the tag resolves to that commit before changing a pin.
- Keep `permissions: {}` at the workflow level and grant each job only what it
  uses. `tests.yml` and `publish.yml`'s `stage-bottles` job run with read-only
  tokens and no `id-token` or `attestations` permissions.
- Before staging or signing, `publish.yml` snapshots `scripts/` from `main` into
  `${RUNNER_TEMP}/trusted-scripts` before applying any PR commits, and enforces:
  execution from `main`; an open same-repository pull request targeting `main`;
  `headRefOid == head_sha` with `behind_by == 0`; no `.github/` or `scripts/`
  changes unless `allow_workflow_changes=true` is explicitly supplied after review;
  every modified `Formula/*.rb` covered across all three target platforms; and
  verified `bottles_<os>` + `provenance_<os>` ZIP digests (`allow_missing_manifest=true`
  is an audited break-glass flag only for pre-provenance PRs).
- `publish.yml` runs `scripts/update-readme-bottles.sh` after merging `bottle do`
  blocks so `README.md`'s fenced `BOTTLE_PROVENANCE_TABLE` stays synchronized with
  `Formula/*.rb` without creating merge conflicts across parallel formula PRs.
- Multi-step CI logic lives in `scripts/ci/` (`common.sh` non-executable sourced
  `ci::*` library, `build-provenance-manifest.sh`, `stage-backfill.sh`,
  `sign-and-attest.sh`, `publish-bottles.sh`, and `verify-patch-policy.sh`) with
  environment-only workflow inputs and regex allowlists.
- `tests.yml` uploads bottles and provenance manifests only from a passing run
  and restores no dependency cache, because its artifacts become release assets.
- Do not pass `token:` to `setup-homebrew` (it writes the token into global Git
  config readable by build steps). Jobs holding write tokens set `stable: true`.
- Never use `pull_request_target` or `workflow_run`, and never expand `${{ }}`
  inside `run:`; pass values through `env:` and validate them in Bash.
- `autobump.yml` uses no `actions/checkout` and authenticates pushes via
  `gh auth setup-git`, keeping tokens out of `.git/config`.
- Lint with `actionlint` and audit with `zizmor --persona=auditor` after every
  workflow change (`publish.yml` and `attest.yml` use `./.github/workflows/sign-bottles.yml`
  with `# zizmor: ignore[self-repository]` for `actionlint` compatibility).
- Residual risks:
  1. Homebrew's built-in `HOMEBREW_VERIFY_ATTESTATIONS=1` / `brew verify` checks
     repository identity (`--repo artagon/homebrew-aitools`) rather than pinning a
     specific workflow SAN; `scripts/verify-provenance.sh` enforces the exact
     `sign-bottles.yml@refs/heads/main` SAN, `--source-ref refs/heads/main`,
     `--deny-self-hosted-runners`, and atomic dual-subject binding.
  2. Formulae packaging prebuilt upstream release archives attest that this tap's
     CI fetched the SHA-256-pinned upstream artifact and built the bottle, not
     that upstream compiled the binary reproducibly from source.
  3. `tests/helpers/agent_install_helper.bash` pins the bundled installer SHA-256
     but not individual hook scripts.

Use [the integration suite](../tests/README.md), [structural ast-grep rules](ast-grep.md),
and [repository tool boundaries](../TOOLS.md) to validate wrapper and formula changes
with real payloads. Verify installation, upgrade, permissions, and `test do`
behavior through real Homebrew commands in an isolated prefix.
