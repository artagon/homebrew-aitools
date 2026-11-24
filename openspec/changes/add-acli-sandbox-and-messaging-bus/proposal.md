# Proposal: `artagon/aitools` Packaging & Lockfile Parity for `acli` and Managed Bus Dependencies

## Why

Packaging `acli` and its managed host dependencies (`agent-mail`, `nats`, `nats-server`, `br`, `bd`) in `artagon/homebrew-aitools` requires hardened `/bin/bash` 3.2 runtime wrappers, unconditional telemetry suppression, loopback-default daemon binding, `Homebrew >= 7.0.5` offline source builds (`std_cargo_fetch_args`, `def fetch`, `deny_network_access!`), exact macOS `acli-shim` `CodeDirectory` `Identifier` + binary slot 5/7 entitlement verification, and per-artifact/platform `versions/aitools-lock.json` parity with Split-System Nix (`--option builders ''`).

> [!NOTE]
> The `acli` Rust runtime workspace (5 host crates, 2 static musl guest crates, `configs/cli-meta/`, and the 5 runtime capability specs `acli-launcher-and-metadata`, `acli-os-and-vm-sandboxing`, `acli-mux-herdr-ntm`, `interagent-messaging-bus`, and `agent-cli-production-telemetry`) now lives in the separate repository `artagon/acli` (`https://github.com/artagon/acli`). This tap change tracks strictly the `artagon/homebrew-aitools` packaging surface (`homebrew-aitools-packaging`).

## What Changes

- **Stage 0 Tap Script, Rule, & CI Prerequisites (Complete on `main`):** Register `"nats-server"` in `rules/ruby/formula-conflicts-same-name.yml`, extend `scripts/install-agent-skills.sh` with `--tool ripwire|agent-mail|acli|all` across all 9 CLIs without a `ripwire` hard dependency, add `scripts/check-aitools-lock.sh` (including `Cargo.lock` pure-Rust `statig 0.4.1` and zero commercial `statsig*` verification), update `scripts/autobump.sh` to co-bump `versions/aitools-lock.json` and `acli` guest musl `resource` blocks, and trigger `lint` on `versions/*` in `scripts/ci/plan-ci.sh`.
- **Stage 1 Hardened Dependency Formulae & Lockfile (Complete on `main`):** Ship 3-OS signed bottles for `Formula/agent-mail.rb` (`0.3.41` `revision 1`), `Formula/nats.rb` (`0.5.2` `revision 1`), standalone `Formula/nats-server.rb` (`2.15.3`, compiling field-independent `libexec/bin/nats-bind-preflight` with zero `acli` dependency and no `service do`), `Formula/br.rb` (`0.7.6` `revision 1`, blocking `br upgrade -> exit 2`), `Formula/bd.rb` (`1.3.4` `revision 2`, unconditionally exporting `BD_DISABLE_METRICS=1 BD_DISABLE_EVENT_FLUSH=1 DOLT_METRICS_DISABLED=1 DO_NOT_TRACK=1`), and `versions/aitools-lock.json` (`acli` marked `"staged"`).
- **Stage 2+ `Formula/acli.rb` & Nix Parity Cutover (Pending `artagon/acli` v0.1.0 release):** Add pure-Rust `Formula/acli.rb` pointing to `https://github.com/artagon/acli` source and static musl guest `resource` release tarballs, direct zero-Bash `bin.install_symlink libexec/"bin/acli"`, `/bin/bash` 3.2 `bin/aclid` wrapper exporting `ACLI_SHIM_PATH`, platform-accurate `libkrun`/`bubblewrap`/`slirp4netns` + `artagon/aitools/{agent-mail,nats-server,br,bd}` dependencies, hypervisor-only `--id com.artagon.acli.shim` slot 5/7 verification, zero Python/DuckDB/`ELv2` runtime deps, and flip `acli` to `status: "present"` in `versions/aitools-lock.json`.

## Capabilities

### New Capabilities

- `homebrew-aitools-packaging`: Hardened `artagon/aitools` formulae (`agent-mail` `0.3.41` `revision 1`, `nats` `0.5.2` `revision 1`, `nats-server` `2.15.3`, `br` `0.7.6` `revision 1`, `bd` `1.3.4` `revision 2`, pure-Rust `acli`, plus companion `phoenix-cli` / `arize-phoenix` / `langfuse-cli` / `openlit` / `mlflow` / optional `artagon-harness-eval` interop) targeting `Homebrew >= 7.0.5` source builds, pinned musl guest `resource`s, exact `CodeDirectory` `Identifier` + binary XML slot 5 / DER slot 7 signing, `ast-grep` rules, tap script extensions, and per-artifact/platform `versions/aitools-lock.json` parity under `--option builders ''`.

### Modified Capabilities

<!-- None: openspec/specs/ currently contains no baseline capability specifications. -->

## Out of Scope

- Implementing the `acli` Rust host/guest crates, `configs/cli-meta/`, or Split-System Nix flake inside `artagon/homebrew-aitools` (owned by `artagon/acli`).
- Mutating live user dotfiles (`~/.claude*`, `~/.codex*`, `~/.config/*`, `~/.homebrew/trust.json`, `~/.sigstore`) during Homebrew install, upgrade, or automated test runs.
- Direct-merging formula PRs outside `publish.yml` (`brew pr-pull` + `.github/workflows/sign-bottles.yml@refs/heads/main`).

## Impact

- **Repository files (`artagon/homebrew-aitools`):** `Formula/agent-mail.rb`, `Formula/nats.rb`, `Formula/nats-server.rb`, `Formula/br.rb`, `Formula/bd.rb`, `Formula/acli.rb` (Stage 2+), `versions/aitools-lock.json`, `scripts/check-aitools-lock.sh`, `scripts/lib/`, `scripts/install-agent-skills.sh`, `scripts/autobump.sh`, `scripts/ci/plan-ci.sh`, `rules/ruby/formula-conflicts-same-name.yml`, `rule-tests/`, `tests/{aitools_lock,install_agent_skills_multitool,stage1_formula_wrappers}.bats`, `.github/workflows/tests.yml`, `README.md`, and `ABOUT.md`.
- **Companion repository (`artagon/acli`):** Owns the Rust source workspace, static musl guest release artifacts, `Cargo.lock` (`statig = "0.4.1"`, zero `statsig*`), Split-System Nix flake, and the 5 runtime OpenSpec capability specifications.
- **Supporting Evidence:**
  - [research/README.md](research/README.md)
  - [research/04-homebrew-aitools-tap-and-nix-parity.md](research/04-homebrew-aitools-tap-and-nix-parity.md)
  - [research/05-adversarial-review-ledger.md](research/05-adversarial-review-ledger.md)
