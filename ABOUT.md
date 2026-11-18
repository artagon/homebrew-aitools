# About — Artagon AI Tools Homebrew Tap (`artagon/aitools`)

## Overview

`artagon/aitools` is a curated Homebrew tap shipping **32** developer tools, MCP servers, local memory stores, evaluation harnesses, OpenTelemetry collectors, subscription-only AI routing & coding agents, and JDK 28 Valhalla-aware AST analyzers for AI coding agents. Published bottles target macOS (`arm64_tahoe`) and Linux (`arm64_linux`, `x86_64_linux`; see [`README.md`](README.md) for per-formula platform coverage) with ref-bound SLSA v1 provenance, signed build lineage, keyless Sigstore `cosign` v3 bundles, and SPDX 2.3 + CycloneDX 1.6 SBOMs.

## Design Guarantees

- **Zero live configuration mutation**: `brew install`, `brew upgrade`, and `brew uninstall` never edit `~/.claude*`, `~/.codex*`, `~/.gemini*`, `~/.config/*`, or shell profiles; bundled skills, plugins, and hooks stage passively under `pkgshare` for explicit opt-in.
- **Hardened local-first & telemetry-off defaults**: Wrappers suppress startup update checks, analytics, and unsolicited cloud routing, default local services and CLIs to loopback (`127.0.0.1`), enforce CLI-subscription-only mode (`magpie`, `omp`, `pi-agent-rust`), and block or warn against in-place self-updaters so upgrades stay under `brew`.
- **Additive JDK 28 Valhalla Java AST support**: Compiles JEP 401/440/511/513 Java syntax (`value` classes/records, constructor prologues before `super(...)`, `import module`, qualified record patterns, and varargs annotations) directly into `ast-grep-valhalla` and `ripwire` while preserving byte-identical parse trees for standard Java.
- **Cryptographic supply-chain provenance**: Staging, OIDC signing (`sign-bottles.yml@refs/heads/main`), and fast-forward publishing are privilege-separated across workflows and verifiable online (`brew verify`, `HOMEBREW_VERIFY_ATTESTATIONS=1`) or air-gapped offline (`scripts/verify-provenance.sh --offline`).

## What's Included

Live upstream versions, SHA-256 digests, and bottle provenance links are maintained in [`Formula/*.rb`](Formula) and [`README.md`](README.md):

| Domain | Formulae |
| :--- | :--- |
| **Code Search, Valhalla Java AST & Hash-Anchored Editing** | `tree-sitter-java-valhalla`, `ast-grep-valhalla`, `ripwire`, `tgrep`, `ck`, `fff-mcp`, `hashline` |
| **Local Agent Memory, Hybrid Markdown Search & Token Compression** | `basic-memory`, `hindsight`, `qmd`, `squeez` |
| **Multi-Agent Coordination, Event Buses & Beads Graph Tracking** | `agent-mail`, `br`, `bd`, `bv`, `nats`, `herdr` |
| **Architecture Decisions, Skill Lifecycle & Benchmarking** | `adrkit`, `agentsync`, `skillfile`, `skillprism`, `waza`, `skillopt` |
| **Evaluation Harnesses, Skill Registries & OpenTelemetry Observability** | `mlflow`, `inspect-ai`, `langfuse-cli`, `phoenix-cli`, `arize-phoenix`, `openlit` |
| **Subscription-Only AI Gateway & Terminal Coding Agents** | `magpie`, `omp`, `pi-agent-rust` |

## Pipeline & Status

- **32 formulae maintained**: **21** built from source (`tree-sitter-java-valhalla`, `ast-grep-valhalla`, `ripwire`, `hashline`, `adrkit`, `nats`, `skillfile`, `skillprism`, `basic-memory`, `hindsight`, `qmd`, `squeez`, `waza`, `skillopt`, `magpie`, `mlflow`, `inspect-ai`, `langfuse-cli`, `phoenix-cli`, `arize-phoenix`, `openlit`) and **11** packaging SHA-256-pinned upstream release archives (`tgrep`, `ck`, `fff-mcp`, `agent-mail`, `br`, `bd`, `bv`, `herdr`, `agentsync`, `omp`, `pi-agent-rust`).
- **Continuous verification**: Pull requests build, test, bottle, and scan SBOMs across `macos-26`, `ubuntu-24.04`, and `ubuntu-24.04-arm` via [`.github/workflows/tests.yml`](.github/workflows/tests.yml), validated locally and in CI by isolated `bats-core` suites across `/bin/bash` 3.2 and Bash 5+.
- **Automated publishing & daily livecheck**: Bottles are attested via [`.github/workflows/sign-bottles.yml`](.github/workflows/sign-bottles.yml), published atomically through [`.github/workflows/publish.yml`](.github/workflows/publish.yml) (with backfill via [`.github/workflows/attest.yml`](.github/workflows/attest.yml)), and checked daily for upstream releases via [`.github/workflows/autobump.yml`](.github/workflows/autobump.yml).

## Quick Links

- [`README.md`](README.md) — quickstart, categorized formula catalog, MCP server registration, bundled skills, and provenance verification
- [`AGENTS.md`](AGENTS.md) — tap maintenance contract for contributors and coding agents
- [`docs/agent-context.md`](docs/agent-context.md) — Valhalla grammar patch, autobump mechanics, bottle publishing, and workflow security
- [`tests/README.md`](tests/README.md) — isolated Bash 3.2 and Bash 5+ installer and provenance `bats-core` test suites
- [`scripts/verify-provenance.sh`](scripts/verify-provenance.sh) & [`scripts/autobump.sh`](scripts/autobump.sh) — online/air-gapped provenance verifier and `brew livecheck` rewriter

## Topics

`homebrew` `homebrew-tap` `ai-agents` `coding-agents` `mcp` `mcp-server` `agent-memory` `agent-skills` `slsa` `sigstore` `cosign` `sbom` `build-provenance` `claude-code` `codex-cli` `antigravity-cli` `tree-sitter` `java-valhalla` `ast-grep` `ripwire` `tgrep` `ck` `fff-mcp` `hashline` `basic-memory` `hindsight` `qmd` `squeez` `beads` `agent-mail` `adr` `agentsync` `skillfile` `skillprism` `waza` `skillopt` `magpie` `omp` `pi-agent-rust` `mlflow` `inspect-ai` `langfuse` `arize-phoenix` `openlit` `opentelemetry`

## Authors & License

Maintained by Artagon & Giedrius Trumpickas. Tap scripts, rules, and formula definitions are licensed under `MIT`. Packaged tools ship under their respective upstream licenses (`MIT`, `Apache-2.0`, `MIT OR Apache-2.0`, `AGPL-3.0-or-later`, `Elastic-2.0`, or `MIT License with OpenAI/Anthropic Rider` installed at `$(brew --prefix <formula>)/LICENSE`); run `brew info artagon/aitools/<formula>` for per-formula license details.
