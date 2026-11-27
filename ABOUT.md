# About — Artagon AI Tools Homebrew Tap (`artagon/aitools`)

## Overview

`artagon/aitools` is a curated Homebrew tap shipping developer CLIs, local MCP servers, memory and context databases, multi-agent orchestration platforms, design intelligence & OpenAPM skill catalogs, skill lifecycle compilers, evaluation harnesses, AI learning companions, OpenTelemetry collectors, subscription-first coding-agent gateways, JDK 28 Valhalla-aware AST analyzers, and macOS native desktop casks for AI coding agents. Published bottles target macOS (`arm64_tahoe`) and Linux (`arm64_linux`, `x86_64_linux`; see [`README.md`](README.md) for per-formula platform coverage) with ref-bound SLSA v1 provenance, signed build lineage, keyless Sigstore `cosign` v3 bundles, and SPDX 2.3 + CycloneDX 1.6 SBOMs.

Live formula and macOS cask definitions, upstream versions, SHA-256 checksums, and bottle provenance links live in [`Formula/*.rb`](Formula), [`Casks/*.rb`](Casks), and [`README.md`](README.md).

## Design Guarantees

- **Zero live dotfile or agent-config mutation**: `brew install`, `brew upgrade`, and `brew uninstall` never edit `~/.claude*`, `~/.codex*`, `~/.gemini*`, `~/.config/*`, `~/.hammerspoon`, or shell profiles; bundled skills, plugins, hooks, and templates stage passively under `pkgshare` for explicit opt-in, while macOS cask `postflight_steps` configure only each app's own `UserDefaults` and guarded single-UTI LaunchServices defaults (opt-out via `HOMEBREW_*_SKIP_DEFAULTS=1`).
- **Hardened local-first & telemetry-off defaults**: Wrappers, source patches, and cask `postflight_steps` suppress startup update checks, telemetry/analytics beacons, and unsolicited cloud or paid-API routing, bind local services and collectors to loopback (`127.0.0.1`), and block or warn against in-place self-updaters so upgrades remain managed by `brew` (signed desktop casks that ignore macOS `UserDefaults` omit `auto_updates true`, document explicit opt-out controls, and provide hardened launcher guidance in caveats and `docs/packages/*/AGENTS.md`).
- **Additive JDK 28 Valhalla Java AST support**: Compiles JEP 401/440/511/513 Java syntax (`value` classes/records, constructor prologues before `super(...)`, `import module`, qualified record patterns, and varargs annotations) into Valhalla-enabled Java AST analyzers while preserving byte-identical parse trees for standard Java.
- **Cryptographic supply-chain provenance**: Staging, OIDC signing (`sign-bottles.yml@refs/heads/main`), and fast-forward publishing are privilege-separated across workflows and verifiable online (`brew verify`, `HOMEBREW_VERIFY_ATTESTATIONS=1`) or air-gapped offline (`scripts/verify-provenance.sh --offline`).

## Capability Domains

1. **Code Intelligence, Valhalla Java AST & Safe Editing** (`9` formulae) — structural AST search/rewriting, call-graph orientation, trigram/hybrid code search, file ranking MCP servers, and hash-anchored patching
2. **Agent Memory, Context Databases & Token Compression** (`6` formulae) — local knowledge graphs, cross-session memory, agent-native context/RAG databases, vector + BM25 Markdown retrieval, and CLI output token compression
3. **Multi-Agent Orchestration, Messaging & Workspaces** (`12` formulae) — multi-agent control planes, agent mail servers, Tailscale MCP relays, pub/sub NATS buses, terminal session multiplexers, Git worktrees, and Beads task graphs
4. **Agent Skills, Personas & Design Intelligence** (`10` formulae) — tap skill registrar (`aitools-skills`), skill managers/compilers/optimizers, native OpenAPM (`pkgshare/apm/<formula>/`) skill packs, multi-division persona catalogs, UI/UX & editorial diagram intelligence, and generated Go CLI catalogs
5. **Evaluation Harnesses & OpenTelemetry Observability** (`7` formulae) — live coding-agent trial runners, workflow/skill benchmarkers, versioned skill registries, and local OTLP trace collectors/workbenches
6. **Coding Agents, Subscription Gateways & AI Companions** (`4` formulae) — subscription-first OAuth routers, terminal coding agents without API-key spend, and agent-native learning companions
7. **Governance, Security Hooks, Templating & Build Speed** (`6` formulae) — ADR governance, credential-guarding hooks, sandboxed MiniJinja CLI and Python 3 template engines, content-addressed build caches, and statistical CLI benchmarking
8. **macOS Native Desktop Casks** (`6` casks) — signed and notarized native macOS terminals, automation tools, Markdown previewers, persona managers, learning apps, and collaborative design workspaces with local-first updater/telemetry controls

## Packaged Tools

<!-- BEGIN ABOUT_INVENTORY -->
<!-- Auto-generated from Formula/*.rb and Casks/*.rb by scripts/update-tap-docs.sh (and refreshed automatically by publish.yml). Do not edit manually. -->

This tap currently packages **60** tools: **54** formulae (**54** bottled, **0** source-only) and **6** macOS casks.

| Tool | Kind | Version | License | Bottles | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [`adrkit`](Formula/adrkit.rb) | Formula | `0.20.0_1` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [mbeacom/adrkit](https://github.com/mbeacom/adrkit) — Architecture governance CLI and MCP server for AI coding agents |
| [`agency-agents`](Formula/agency-agents.rb) | Formula | `2026.11.09` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — Specialized AI agent persona catalog and multi-tool installer |
| [`agent-mail`](Formula/agent-mail.rb) | Formula | `0.3.41_1` | Custom (`LICENSE`) | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [Dicklesworthstone/mcp_agent_mail_rust](https://github.com/Dicklesworthstone/mcp_agent_mail_rust) — Asynchronous coordination MCP server and CLI for AI coding agents |
| [`agent-skills`](Formula/agent-skills.rb) | Formula | `0.6.18_1` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) — Production-grade software engineering skills and checklists for AI agents |
| [`agent-tincan`](Formula/agent-tincan.rb) | Formula | `0.32.0` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [agenttincan.com](https://agenttincan.com) — Tailscale-based relay and MCP bridge for AI agent collaboration |
| [`agenthooks`](Formula/agenthooks.rb) | Formula | `0.7.7` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [speakeasy-api/agenthooks](https://github.com/speakeasy-api/agenthooks) — Cross-agent hook Go library and credential-scanning hook runner |
| [`agentsync`](Formula/agentsync.rb) | Formula | `1.53.2` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [dallay/agentsync](https://github.com/dallay/agentsync) — Sync AI agent configurations and MCP servers via symbolic links |
| [`aitools-skills`](Formula/aitools-skills.rb) | Formula | `0.1.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [artagon/aitools-skills](https://github.com/artagon/aitools-skills) — Offline-first Homebrew agent skill registrar for artagon/aitools |
| [`arize-phoenix`](Formula/arize-phoenix.rb) | Formula | `22.0.1` | `Elastic-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [arize.com/docs/phoenix](https://arize.com/docs/phoenix) — Local-first OpenTelemetry AI observability and evaluation server |
| [`ast-grep-valhalla`](Formula/ast-grep-valhalla.rb) | Formula | `0.51.3` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [ast-grep.github.io](https://ast-grep.github.io/) — Code searching, linting, rewriting with a Valhalla-aware Java grammar |
| [`autoswarm`](Formula/autoswarm.rb) | Formula | `0.1.1` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [HKUDS/AutoSwarm](https://github.com/HKUDS/AutoSwarm) — Coordinate installed coding agents from one conversation |
| [`basic-memory`](Formula/basic-memory.rb) | Formula | `1.0.0` | `AGPL-3.0-or-later` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [basicmachines-co/basic-memory](https://github.com/basicmachines-co/basic-memory) — Local-first knowledge graph and stdio MCP server for AI agents |
| [`bd`](Formula/bd.rb) | Formula | `1.3.4_2` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [gastownhall/beads](https://github.com/gastownhall/beads) — Git-backed graph issue tracker for AI coding agents |
| [`br`](Formula/br.rb) | Formula | `0.7.6_1` | Custom (`LICENSE`) | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [Dicklesworthstone/beads_rust](https://github.com/Dicklesworthstone/beads_rust) — Local-first issue tracker for AI coding agents |
| [`bv`](Formula/bv.rb) | Formula | `0.27.0` | Custom (`LICENSE`) | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [Dicklesworthstone/beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) — Graph-aware terminal viewer and triage engine for Beads projects |
| [`cairn`](Formula/cairn.rb) | Formula | `0.2.1` | `AGPL-3.0-only` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [oritera/Cairn](https://github.com/oritera/Cairn) — Blackboard fact-intent graph server and dispatcher for AI agents |
| [`ck`](Formula/ck.rb) | Formula | `0.8.1_1` | `MIT OR Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [BeaconBay/ck](https://github.com/BeaconBay/ck) — Local semantic and hybrid BM25 code search with an MCP server |
| [`claude-mem`](Formula/claude-mem.rb) | Formula | `16.1.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) — Persistent cross-session memory CLI and local MCP server for coding agents |
| [`codesearch`](Formula/codesearch.rb) | Formula | `1.8.11` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [flupkede/codesearch](https://github.com/flupkede/codesearch) — Multi-repo semantic code search CLI and MCP server |
| [`deeptutor`](Formula/deeptutor.rb) | Formula | `1.7.4_1` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [HKUDS/DeepTutor](https://github.com/HKUDS/DeepTutor) — Agent-native intelligent learning companion CLI and SDK |
| [`diagram-design`](Formula/diagram-design.rb) | Formula | `2.6.178_1` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) — Editorial HTML and SVG diagram skill across 52 types for AI coding agents |
| [`entire-graph`](Formula/entire-graph.rb) | Formula | `0.6.0` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [entireio/entire-graph](https://github.com/entireio/entire-graph) — Deterministic local code graph for coding agents |
| [`fff-mcp`](Formula/fff-mcp.rb) | Formula | `0.11.0_1` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [dmtrKovalenko/fff](https://github.com/dmtrKovalenko/fff) — Fast, frecency-ranked file search MCP server for AI agents |
| [`hashline`](Formula/hashline.rb) | Formula | `0.9.24_1` | `MIT OR Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [quangdang46/hashline](https://github.com/quangdang46/hashline) — Hash-anchored line editing for AI coding agents |
| [`herdr`](Formula/herdr.rb) | Formula | `0.9.5_1` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [herdrdev/herdr](https://github.com/herdrdev/herdr) — Multiplexed terminal manager for AI coding agent sessions |
| [`hindsight`](Formula/hindsight.rb) | Formula | `1.2.3` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [vectorize-io/hindsight](https://github.com/vectorize-io/hindsight) — Semantic agent memory CLI and local MCP server |
| [`hyperfine`](Formula/hyperfine.rb) | Formula | `2.0.0` | `MIT OR Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [sharkdp/hyperfine](https://github.com/sharkdp/hyperfine) — Command-line benchmarking tool |
| [`inspect-ai`](Formula/inspect-ai.rb) | Formula | `0.3.291` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [inspect.aisi.org.uk](https://inspect.aisi.org.uk/) — Agentic LLM evaluation harness bundling Inspect SWE and MLflow hooks |
| [`kache`](Formula/kache.rb) | Formula | `2.3.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [kunobi-ninja/kache](https://github.com/kunobi-ninja/kache) — Zero-copy, content-addressed build cache for Rust, C/C++, and CUDA |
| [`langfuse-cli`](Formula/langfuse-cli.rb) | Formula | `1.4.0` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [langfuse/langfuse-cli](https://github.com/langfuse/langfuse-cli) — Command-line client for Langfuse API and versioned agent skills |
| [`magpie`](Formula/magpie.rb) | Formula | `0.1.4704` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [usemagpie.ai](https://usemagpie.ai) — Subscription-first local gateway and router for AI coding agents |
| [`minijinja-cli`](Formula/minijinja-cli.rb) | Formula | `3.1.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [mitsuhiko/minijinja](https://github.com/mitsuhiko/minijinja) — Render Jinja2 templates directly from the command-line to stdout |
| [`mlflow`](Formula/mlflow.rb) | Formula | `3.18.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [mlflow.org](https://mlflow.org) — AI evaluation, trace, dataset, and skill registry platform with agent CLIs |
| [`nats-server`](Formula/nats-server.rb) | Formula | `2.15.3` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [nats.io](https://nats.io) — Lightweight cloud messaging system |
| [`nats`](Formula/nats.rb) | Formula | `0.5.2_1` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [nats-io/natscli](https://github.com/nats-io/natscli) — Utility to interact with and manage NATS messaging systems |
| [`omp`](Formula/omp.rb) | Formula | `19.1.1` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [omp.sh](https://omp.sh) — Terminal AI coding agent with Rust native core, LSP, and DAP |
| [`openlit`](Formula/openlit.rb) | Formula | `2.2.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [openlit/openlit](https://github.com/openlit/openlit) — OpenTelemetry collector CLI for AI coding agents |
| [`openviking`](Formula/openviking.rb) | Formula | `0.5.6` | `AGPL-3.0-only` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [volcengine/OpenViking](https://github.com/volcengine/OpenViking) — Agent-native context database for AI memory, RAG, and skills |
| [`paperclip`](Formula/paperclip.rb) | Formula | `2026.1117.0` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [paperclip.ing](https://paperclip.ing) — Open-source orchestration platform and CLI for teams of AI agents |
| [`phoenix-cli`](Formula/phoenix-cli.rb) | Formula | `1.24.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [arize.com/docs/phoenix](https://arize.com/docs/phoenix) — Command-line trace, dataset, experiment, and agent setup client for Phoenix |
| [`pi-agent-rust`](Formula/pi-agent-rust.rb) | Formula | `0.9.0` | Custom (`LICENSE`) | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [Dicklesworthstone/pi_agent_rust](https://github.com/Dicklesworthstone/pi_agent_rust) — Safe-Rust AI coding agent CLI with hashline editing |
| [`printing-press-library`](Formula/printing-press-library.rb) | Formula | `0.1.27` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [printingpress.dev](https://printingpress.dev) — Catalog and installer CLI for Printing Press-generated Go CLIs and skills |
| [`python-minijinja`](Formula/python-minijinja.rb) | Formula | `3.1.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [mitsuhiko/minijinja](https://github.com/mitsuhiko/minijinja) — Python bindings for the MiniJinja Rust template engine |
| [`qmd`](Formula/qmd.rb) | Formula | `2.9.0` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [tobi/qmd](https://github.com/tobi/qmd) — On-device hybrid BM25 and vector search CLI and MCP server |
| [`ripwire`](Formula/ripwire.rb) | Formula | `0.6.10` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [redhat-et/ripwire](https://github.com/redhat-et/ripwire) — Codebase symbol maps and call graphs for AI agents |
| [`skillfile`](Formula/skillfile.rb) | Formula | `1.9.3` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [eljulians/skillfile](https://github.com/eljulians/skillfile) — Declarative package manager for AI coding agent skills |
| [`skillopt`](Formula/skillopt.rb) | Formula | `0.2.0` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [microsoft/SkillOpt](https://github.com/microsoft/SkillOpt) — Text-space optimizer and offline sleep consolidation for AI agent skills |
| [`skillprism`](Formula/skillprism.rb) | Formula | `0.6.0` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [Tuvren/skillprism](https://github.com/Tuvren/skillprism) — Template compiler for multi-harness AI coding agent skills |
| [`squeez`](Formula/squeez.rb) | Formula | `1.49.3_1` | `Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [claudioemmanuel/squeez](https://github.com/claudioemmanuel/squeez) — Token compressor and stdio MCP server for AI coding agents |
| [`tgrep`](Formula/tgrep.rb) | Formula | `1.2.8` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [microsoft/tgrep](https://github.com/microsoft/tgrep) — Trigram-indexed grep for fast regex search in large codebases |
| [`tree-sitter-java-valhalla`](Formula/tree-sitter-java-valhalla.rb) | Formula | `0.23.5` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [tree-sitter/tree-sitter-java](https://github.com/tree-sitter/tree-sitter-java) — Tree-sitter Java grammar with JDK 28 Valhalla value classes and records |
| [`ui-ux-pro-max-cli`](Formula/ui-ux-pro-max-cli.rb) | Formula | `2.15.0_1` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — UI/UX design intelligence CLI, searchable database, and agent skills |
| [`waza`](Formula/waza.rb) | Formula | `0.42.0` | `MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [microsoft.github.io/waza](https://microsoft.github.io/waza/) — Evaluate and benchmark AI agent workflows, custom agents, and skills |
| [`worktrunk`](Formula/worktrunk.rb) | Formula | `0.83.0` | `Apache-2.0 OR MIT` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [worktrunk.dev](https://worktrunk.dev) — CLI for Git worktree management, designed for parallel AI agent workflows |
| [`agency-agents`](Casks/agency-agents.rb) | Cask | `0.3.2` | — | macOS cask | [agencyagents.app](https://agencyagents.app/) — Native desktop manager for installing and tracking AI agent personas |
| [`deeptutor`](Casks/deeptutor.rb) | Cask | `1.7.4` | — | macOS cask | [HKUDS/DeepTutor](https://github.com/HKUDS/DeepTutor) — Agent-native intelligent learning companion desktop app |
| [`ghostty`](Casks/ghostty.rb) | Cask | `1.4.0` | — | macOS cask | [ghostty.org](https://ghostty.org/) — Terminal emulator that uses platform-native UI and GPU acceleration |
| [`hammerspoon`](Casks/hammerspoon.rb) | Cask | `1.1.1` | — | macOS cask | [www.hammerspoon.org](https://www.hammerspoon.org/) — Desktop automation application |
| [`markdown-preview`](Casks/markdown-preview.rb) | Cask | `0.0.74` | — | macOS cask | [markdownpreview.app](https://markdownpreview.app/) — Markdown previewer with bundled Quick Look extension |
| [`open-design`](Casks/open-design.rb) | Cask | `0.27.2` | — | macOS cask | [open-design.ai](https://open-design.ai/) — Collaborative AI design agent workspace |
<!-- END ABOUT_INVENTORY -->

## Pipeline & Verification

- **Continuous verification**: Pull requests run `lint` (`ubuntu-24.04`), structural `ast-grep` rules ([`sgconfig.yml`](sgconfig.yml)), isolated `bats-core` suites, and Linux `brew test-bot` builds (`ubuntu-24.04`, `ubuntu-24.04-arm`) via [`.github/workflows/tests.yml`](.github/workflows/tests.yml), opting into `macos-26` (`arm64_tahoe`) bottle builds via `include_macos=true` or the `build-macos-bottles` PR label before publishing.
- **Automated publishing & daily livecheck**: Bottles are attested via [`.github/workflows/sign-bottles.yml`](.github/workflows/sign-bottles.yml), published atomically through [`.github/workflows/publish.yml`](.github/workflows/publish.yml) (with backfill via [`.github/workflows/attest.yml`](.github/workflows/attest.yml)), and checked daily for upstream releases via [`.github/workflows/autobump.yml`](.github/workflows/autobump.yml).

## Quick Links

- [`README.md`](README.md) — quickstart, 8-domain taxonomy, categorized formula catalog, MCP server registration, bundled skills, and bottle provenance table
- [`docs/packages/README.md`](docs/packages/README.md) — per-package `AGENTS.md` guides with configuration paths, upstream vs. tap-hardened defaults, and opt-in setup rules
- [`AGENTS.md`](AGENTS.md) & [`CLAUDE.md`](CLAUDE.md) — tap maintenance contract for contributors and coding agents
- [`TOOLS.md`](TOOLS.md) & [`docs/ast-grep.md`](docs/ast-grep.md) — code-intelligence tool routing, static-analysis boundaries, and structural rules
- [`docs/agent-context.md`](docs/agent-context.md) — formula hardening, Valhalla grammar patch, autobump mechanics, bottle publishing, and workflow security
- [`tests/README.md`](tests/README.md) — isolated `/bin/bash` 3.2 and Bash 5+ installer and provenance `bats-core` test suites
- [`scripts/verify-provenance.sh`](scripts/verify-provenance.sh), [`scripts/update-tap-docs.sh`](scripts/update-tap-docs.sh), & [`scripts/autobump.sh`](scripts/autobump.sh) — online/air-gapped provenance verifier, deterministic `README.md`/`ABOUT.md` inventory generator, and `brew livecheck` rewriter

## Topics

`homebrew` `homebrew-tap` `ai-agents` `coding-agents` `mcp` `mcp-server` `agent-memory` `agent-skills` `code-search` `ast-grep` `tree-sitter` `java-valhalla` `opentelemetry` `llm-evaluation` `slsa` `sigstore` `cosign` `sbom` `build-provenance` `claude-code` `codex-cli` `antigravity-cli`

## Authors & License

Maintained by Artagon & Giedrius Trumpickas. Tap scripts, rules, and formula definitions are licensed under `MIT`. Packaged tools ship under their respective upstream licenses (standard SPDX licenses or custom-rider licenses installed at `$(brew --prefix <formula>)/LICENSE`); run `brew info artagon/aitools/<formula>` for per-formula license details.
