# About — Artagon AI Tools Homebrew Tap

> **One-liner**: Curated Homebrew tap (`artagon/aitools`) shipping 21 AI coding-agent tools — JDK 28 Valhalla AST and call-graph analyzers, indexed/semantic/hybrid search (`tgrep`, `ck`, `fff-mcp`, `qmd`), hash-anchored editing (`hashline`), local agent memory & token compression (`basic-memory`, `hindsight`, `squeez`), multi-agent mail and Beads trackers, and ADR/skill managers with SLSA v1 attested, Sigstore-signed `macos-26` Apple Silicon bottles and SBOMs.

## What it is

A Homebrew tap (`artagon/aitools`) shipping:

1. **JDK 28 Valhalla Java grammar & structural analyzers** — `tree-sitter-java-valhalla` (`0.23.5`), `ast-grep-valhalla` (`0.51.1`), and `ripwire` (`0.6.9`, paired with `ripwire-agent-install` / [`scripts/install-agent-skills.sh`](scripts/install-agent-skills.sh) for opt-in skills and hooks across 6 coding-agent CLIs)
2. **Code search, hybrid markdown search, file ranking, and hash-anchored editing** — `tgrep` (`1.2.6`), `ck` (`0.8.1`), `fff-mcp` (`0.11.0`), `qmd` (`2.8.3`, local BM25 + `sqlite-vec` + GGUF reranking + MCP + skill), and `hashline` (`0.9.24`, CLI + stdio MCP server + bundled `SKILL.md`)
3. **Local agent memory & token compression (hardened local/loopback defaults)** — `basic-memory` (`1.0.0`, local stdio JSON-RPC MCP + CLI + bundled skills; cloud/HTTP/SSE disabled), `hindsight` (`1.2.1` CLI + `0.8.7` coding-agents stdio MCP + skills; loopback `127.0.0.1`/`::1`/`localhost` only, cloud disabled), and `squeez` (`1.49.3`, CLI + stdio MCP with `auto_compress_md=false`, `persona=off`, `wrap_bash=false`)
4. **Multi-agent messaging, coordination, and Beads graph tracking** — `agent-mail` (`0.3.40`, `mcp-agent-mail` + `am`), `br` (`0.7.6`), `bd` (`1.3.4`), `bv` (`0.26.0`), `nats` (`0.5.1`), and `herdr` (`0.9.5`)
5. **Architecture decisions and agent skill/config lifecycle** — `adrkit` (`0.20.0`, `adr` + `adrkit` + `adrkit-mcp` + bundled skills), `agentsync` (`1.53.1`), `skillfile` (`1.9.2`), and `skillprism` (`0.5.0`)
6. **Automated bottle publishing, cryptographic provenance, & daily livecheck pipelines** — [`tests.yml`](.github/workflows/tests.yml) (`brew test-bot` + Anchore `syft` SBOMs on `macos-26`), [`sign-bottles.yml`](.github/workflows/sign-bottles.yml) (reusable OIDC SLSA v1 + Sigstore `cosign` v3 signer), [`publish.yml`](.github/workflows/publish.yml) (`brew pr-pull` staging + release publishing + `brew verify`), [`attest.yml`](.github/workflows/attest.yml) (provenance backfill), [`scripts/verify-provenance.sh`](scripts/verify-provenance.sh), and [`autobump.yml`](.github/workflows/autobump.yml) / [`scripts/autobump.sh`](scripts/autobump.sh)

## What problem it solves

AI coding-agent CLIs and MCP servers scatter across language-specific package managers (`cargo`, `bun`, `go`) and `curl | bash` installers that mutate live agent configs or nag about self-updates on startup, while upstream Java tree-sitter tools fail on JDK 28 Valhalla syntax. This tap standardizes installation and maintenance under `brew`:

- **Additive JDK 28 Valhalla Java support** compiled directly into `ast-grep-valhalla` and `ripwire` (`value` classes/records, constructor prologues before `super(...)`, `import module`, qualified record patterns, and varargs annotations)
- **Non-invasive installs** that never modify `~/.claude.json`, `~/.codex/config.toml`, `~/.gemini/*`, or shell profiles during `brew install`, `brew upgrade`, or `brew uninstall`
- **Homebrew-managed upgrades** with startup update checks disabled in wrappers (`HASHLINE_NO_UPDATE_CHECK=1`, `AGENTSYNC_NO_UPDATE_CHECK=1`, `SKILLFILE_NO_UPDATE_NOTIFIER=1`) and explicit `caveats` against in-place self-updaters
- **Auditable release hygiene & cryptographic provenance** with literal versioned URLs, SHA-256 verification, full upstream license installation for custom-rider packages (`license :cannot_represent`), SLSA v1 build provenance (`HOMEBREW_VERIFY_ATTESTATIONS=1`), Sigstore `cosign` v3 bundles, and SPDX 2.3 + CycloneDX SBOMs

## Status

- 21 formulae maintained: 12 built from source (`tree-sitter-java-valhalla`, `ast-grep-valhalla`, `ripwire`, `hashline`, `adrkit`, `nats`, `skillfile`, `skillprism`, `basic-memory`, `hindsight`, `qmd`, `squeez`) and 9 packaging pinned upstream release binaries (`tgrep`, `ck`, `fff-mcp`, `agent-mail`, `br`, `bd`, `bv`, `herdr`, `agentsync`)
- Pull requests build, test, bottle, and generate SBOMs on `macos-26` Apple Silicon via [`.github/workflows/tests.yml`](.github/workflows/tests.yml) and run isolated Bash 3.2 and Bash 5+ suites ([`tests/integration-agent-install.sh`](tests/integration-agent-install.sh) and [`tests/test-verify-provenance.sh`](tests/test-verify-provenance.sh))
- Bottles are signed and attested via [`.github/workflows/sign-bottles.yml`](.github/workflows/sign-bottles.yml), published through [`.github/workflows/publish.yml`](.github/workflows/publish.yml) (or backfilled via [`.github/workflows/attest.yml`](.github/workflows/attest.yml)), and checked daily for upstream updates via [`.github/workflows/autobump.yml`](.github/workflows/autobump.yml)

## Topics for repo discovery

`homebrew` `homebrew-tap` `ai-agents` `coding-agents` `mcp` `mcp-server` `agent-memory` `agent-skills` `slsa` `sigstore` `cosign` `sbom` `build-provenance` `claude-code` `codex-cli` `antigravity-cli` `tree-sitter` `java-valhalla` `ast-grep` `ripwire` `tgrep` `ck` `fff-mcp` `hashline` `basic-memory` `hindsight` `qmd` `squeez` `beads` `agent-mail` `adr` `agentsync` `skillfile` `skillprism`

## Quick links

- [`README.md`](README.md) — install paths, per-formula usage, MCP registration tables, provenance verification, and skill directories
- [`AGENTS.md`](AGENTS.md) — tap maintenance rules for contributors and coding agents
- [`docs/agent-context.md`](docs/agent-context.md) — Valhalla grammar patch, autobump mechanics, bottle publishing, build provenance, and workflow security
- [`tests/README.md`](tests/README.md) — isolated Bash 3.2 and Bash 5+ installer and provenance test suites
- [`scripts/verify-provenance.sh`](scripts/verify-provenance.sh) — online and air-gapped SLSA v1, Sigstore `cosign` v3, SBOM, and `brew verify` checker
- [`scripts/autobump.sh`](scripts/autobump.sh) — `brew livecheck` URL and SHA-256 rewrite automation

## Authors

Artagon & Giedrius Trumpickas

## License

Tap scripts and formula definitions: MIT. Packaged tools are distributed under their respective upstream licenses (`MIT`, `Apache-2.0`, `MIT OR Apache-2.0`, or `MIT License with OpenAI/Anthropic Rider` installed at `$(brew --prefix <formula>)/LICENSE`); run `brew info artagon/aitools/<formula>` for per-formula license details.
