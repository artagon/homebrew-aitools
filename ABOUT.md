# About — Artagon AI Tools Homebrew Tap (`artagon/aitools`)

## Overview

`artagon/aitools` is a curated Homebrew tap shipping developer CLIs, local MCP servers, memory and search engines, multi-agent coordination tools, skill lifecycle compilers, evaluation harnesses, OpenTelemetry collectors, subscription-first coding-agent gateways, and JDK 28 Valhalla-aware AST analyzers for AI coding agents. Published bottles target macOS (`arm64_tahoe`) and Linux (`arm64_linux`, `x86_64_linux`; see [`README.md`](README.md) for per-formula platform coverage) with ref-bound SLSA v1 provenance, signed build lineage, keyless Sigstore `cosign` v3 bundles, and SPDX 2.3 + CycloneDX 1.6 SBOMs.

Live formula and macOS cask definitions, upstream versions, SHA-256 checksums, and bottle provenance links live in [`Formula/*.rb`](Formula), [`Casks/*.rb`](Casks), and [`README.md`](README.md).

## Design Guarantees

- **Zero live dotfile or agent-config mutation**: `brew install`, `brew upgrade`, and `brew uninstall` never edit `~/.claude*`, `~/.codex*`, `~/.gemini*`, `~/.config/*`, `~/.hammerspoon`, or shell profiles; bundled skills, plugins, hooks, and templates stage passively under `pkgshare` for explicit opt-in, while macOS cask `postflight_steps` configure only each app's own `UserDefaults` and guarded single-UTI LaunchServices defaults (opt-out via `HOMEBREW_*_SKIP_DEFAULTS=1`).
- **Hardened local-first & telemetry-off defaults**: Wrappers, source patches, and cask `postflight_steps` suppress startup update checks, telemetry/analytics beacons, and unsolicited cloud or paid-API routing, bind local services and collectors to loopback (`127.0.0.1`), and block or warn against in-place self-updaters so upgrades remain managed by `brew`.
- **Additive JDK 28 Valhalla Java AST support**: Compiles JEP 401/440/511/513 Java syntax (`value` classes/records, constructor prologues before `super(...)`, `import module`, qualified record patterns, and varargs annotations) into Valhalla-enabled Java AST analyzers while preserving byte-identical parse trees for standard Java.
- **Cryptographic supply-chain provenance**: Staging, OIDC signing (`sign-bottles.yml@refs/heads/main`), and fast-forward publishing are privilege-separated across workflows and verifiable online (`brew verify`, `HOMEBREW_VERIFY_ATTESTATIONS=1`) or air-gapped offline (`scripts/verify-provenance.sh --offline`).

## Capability Domains

- **Code Search, Valhalla Java AST & Hash-Anchored Editing** — structural AST search/rewriting, call-graph orientation, trigram/hybrid code search, file ranking MCP servers, and hash-anchored patching
- **Local Agent Memory, Hybrid Markdown Search & Token Compression** — local knowledge graphs, vector + BM25 Markdown retrieval, and CLI output token compression
- **Multi-Agent Coordination, Event Buses & Graph Issue Tracking** — agent mail servers, terminal session multiplexers, pub/sub buses, and Git-backed issue graphs
- **Architecture Decisions, Skill Lifecycle & Benchmarking** — ADR governance, multi-harness skill compilers/validators, and skill evaluation/optimization suites
- **Evaluation Harnesses, Skill Registries & OpenTelemetry Observability** — live coding-agent trial runners, versioned skill registries, and local OTLP trace collectors/workbenches
- **Subscription-First Local Gateways & Terminal Coding Agents** — loopback routing and terminal coding agents authenticated via CLI subscriptions without ambient API-key spend

## Pipeline & Verification

- **Continuous verification**: Pull requests build, test, bottle, and generate SBOMs across `macos-26`, `ubuntu-24.04`, and `ubuntu-24.04-arm` via [`.github/workflows/tests.yml`](.github/workflows/tests.yml), gated by structural `ast-grep` rules ([`sgconfig.yml`](sgconfig.yml)) and isolated `bats-core` suites across `/bin/bash` 3.2 and Bash 5+.
- **Automated publishing & daily livecheck**: Bottles are attested via [`.github/workflows/sign-bottles.yml`](.github/workflows/sign-bottles.yml), published atomically through [`.github/workflows/publish.yml`](.github/workflows/publish.yml) (with backfill via [`.github/workflows/attest.yml`](.github/workflows/attest.yml)), and checked daily for upstream releases via [`.github/workflows/autobump.yml`](.github/workflows/autobump.yml).

## Quick Links

- [`README.md`](README.md) — quickstart, categorized formula catalog, MCP server registration, bundled skills, and bottle provenance table
- [`AGENTS.md`](AGENTS.md) & [`CLAUDE.md`](CLAUDE.md) — tap maintenance contract for contributors and coding agents
- [`TOOLS.md`](TOOLS.md) & [`docs/ast-grep.md`](docs/ast-grep.md) — code-intelligence tool routing, static-analysis boundaries, and structural rules
- [`docs/agent-context.md`](docs/agent-context.md) — formula hardening, Valhalla grammar patch, autobump mechanics, bottle publishing, and workflow security
- [`tests/README.md`](tests/README.md) — isolated `/bin/bash` 3.2 and Bash 5+ installer and provenance `bats-core` test suites
- [`scripts/verify-provenance.sh`](scripts/verify-provenance.sh) & [`scripts/autobump.sh`](scripts/autobump.sh) — online/air-gapped provenance verifier and `brew livecheck` rewriter

## Topics

`homebrew` `homebrew-tap` `ai-agents` `coding-agents` `mcp` `mcp-server` `agent-memory` `agent-skills` `code-search` `ast-grep` `tree-sitter` `java-valhalla` `opentelemetry` `llm-evaluation` `slsa` `sigstore` `cosign` `sbom` `build-provenance` `claude-code` `codex-cli` `antigravity-cli`

## Authors & License

Maintained by Artagon & Giedrius Trumpickas. Tap scripts, rules, and formula definitions are licensed under `MIT`. Packaged tools ship under their respective upstream licenses (standard SPDX licenses or custom-rider licenses installed at `$(brew --prefix <formula>)/LICENSE`); run `brew info artagon/aitools/<formula>` for per-formula license details.
