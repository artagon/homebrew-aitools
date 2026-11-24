# `artagon/homebrew-aitools` Packaging & Lockfile Parity — Research Suite

**Date:** 2026-11-23  
**Change:** `add-acli-sandbox-and-messaging-bus`  
**Repository:** `artagon/homebrew-aitools` (companion Rust runtime repository: `artagon/acli`)

> [!NOTE]
> The five runtime research documents (`01-canonical-cli-launcher-and-metadata.md`, `02-os-sandbox-and-shared-libkrun-nix-vm.md`, `03-interagent-messaging-and-bus-survey.md`, `06-production-agent-cli-and-hook-telemetry.md`, and `07-rust-hsm-state-machine-architecture.md`) and five runtime capability specs moved with the `acli` Rust workspace into `artagon/acli`. This directory retains the tap packaging research and the full Rounds 1–18 adversarial convergence ledger backing `specs/homebrew-aitools-packaging/spec.md`.

## Research Document Index

| Document | Scope | Primary Evidence Covered |
| --- | --- | --- |
| [04-homebrew-aitools-tap-and-nix-parity.md](04-homebrew-aitools-tap-and-nix-parity.md) | **`artagon/aitools` Homebrew Formulas & Split-System Nix Parity** | `Homebrew >= 7.0.5` source-build floor (`std_cargo_fetch_args`), hardened `agent-mail.rb` (`0.3.41_1`), `nats.rb` (`0.5.2_1`), Stage-1 `nats-server.rb` (`2.15.3`, field-independent Go `libexec/bin/nats-bind-preflight`), `br.rb` (`0.7.6_1` blocking `br upgrade -> exit 2`), `bd.rb` (`1.3.4_2` unconditional telemetry suppression), pure-Rust `acli.rb` (zero-Bash `bin/acli` symlink + `bin/aclid` wrapper + exact `CodeDirectory` `Identifier` and slot 5/7 `hypervisor == true`), guest EROFS exclusion of `bd`/`br`, per-arch Linux `bd` ELF relocation, and `versions/aitools-lock.json`. |
| [05-adversarial-review-ledger.md](05-adversarial-review-ledger.md) | **Rounds 1–18 Dual-Swarm Adversarial Review Ledger (`640` Findings — `6/6` Converged)** | Full dual-swarm remediation history achieving `0` Critical & `0` High across all 6 reviewers in Round 18. |

## Traceability Matrix

| OpenSpec Capability Spec | Normative Scope | Backing Research Documents |
| --- | --- | --- |
| [`homebrew-aitools-packaging`](../specs/homebrew-aitools-packaging/spec.md) | `Homebrew >= 7.0.5` source-build floor, Stage-1 hardened formulae (`agent-mail`, `nats`, `nats-server`, `br`, `bd`), pure-Rust `Formula/acli.rb`, exact `CodeDirectory` `Identifier` + slot 5/7 verification, tap script extensions, and per-artifact/platform `versions/aitools-lock.json` parity under `--option builders ''`. | [04-homebrew-aitools-tap-and-nix-parity.md](04-homebrew-aitools-tap-and-nix-parity.md) · [05-adversarial-review-ledger.md](05-adversarial-review-ledger.md) |
