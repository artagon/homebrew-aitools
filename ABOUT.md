# About — Artagon AI Tools Homebrew Tap

> **One-liner**: Curated Homebrew tap (`artagon/aitools`) shipping 17 AI coding-agent tools — JDK 28 Valhalla AST and call-graph analyzers, indexed and semantic code search, hash-anchored editing, multi-agent mail and Beads trackers, and ADR/skill managers with automated `macos-26` Apple Silicon bottles.

## What it is

A Homebrew tap (`artagon/aitools`) shipping:

1. **JDK 28 Valhalla Java grammar & structural analyzers** — `tree-sitter-java-valhalla` (`0.23.5`), `ast-grep-valhalla` (`0.51.1`), and `ripwire` (`0.6.9`, paired with `ripwire-agent-install` / [`scripts/install-agent-skills.sh`](scripts/install-agent-skills.sh) for opt-in skills and hooks across 6 coding-agent CLIs)
2. **Code search, file ranking, and hash-anchored editing** — `tgrep` (`1.2.6`), `ck` (`0.8.1`), `fff-mcp` (`0.11.0`), and `hashline` (`0.9.24`, CLI + stdio MCP server + bundled `SKILL.md`)
3. **Multi-agent messaging, coordination, and Beads graph tracking** — `agent-mail` (`0.3.40`, `mcp-agent-mail` + `am`), `br` (`0.7.6`), `bd` (`1.3.4`), `bv` (`0.26.0`), `nats` (`0.5.1`), and `herdr` (`0.9.5`)
4. **Architecture decisions and agent skill/config lifecycle** — `adrkit` (`0.20.0`, `adr` + `adrkit` + `adrkit-mcp` + bundled skills), `agentsync` (`1.53.1`), `skillfile` (`1.9.2`), and `skillprism` (`0.5.0`)
5. **Automated bottle publishing & daily livecheck pipelines** — [`tests.yml`](.github/workflows/tests.yml) (`brew test-bot` on `macos-26`), [`publish.yml`](.github/workflows/publish.yml) (`brew pr-pull` to GitHub Releases), and [`autobump.yml`](.github/workflows/autobump.yml) / [`scripts/autobump.sh`](scripts/autobump.sh)

## What problem it solves

AI coding-agent CLIs and MCP servers scatter across language-specific package managers (`cargo`, `bun`, `go`) and `curl | bash` installers that mutate live agent configs or nag about self-updates on startup, while upstream Java tree-sitter tools fail on JDK 28 Valhalla syntax. This tap standardizes installation and maintenance under `brew`:

- **Additive JDK 28 Valhalla Java support** compiled directly into `ast-grep-valhalla` and `ripwire` (`value` classes/records, constructor prologues before `super(...)`, `import module`, qualified record patterns, and varargs annotations)
- **Non-invasive installs** that never modify `~/.claude.json`, `~/.codex/config.toml`, `~/.gemini/*`, or shell profiles during `brew install`, `brew upgrade`, or `brew uninstall`
- **Homebrew-managed upgrades** with startup update checks disabled in wrappers (`HASHLINE_NO_UPDATE_CHECK=1`, `AGENTSYNC_NO_UPDATE_CHECK=1`, `SKILLFILE_NO_UPDATE_NOTIFIER=1`) and explicit `caveats` against in-place self-updaters
- **Auditable release hygiene** with literal versioned URLs, SHA-256 verification, full upstream license installation for custom-rider packages (`license :cannot_represent`), and `brew pr-pull` bottle publishing

## Status

- 17 formulae maintained: 8 built from source (`tree-sitter-java-valhalla`, `ast-grep-valhalla`, `ripwire`, `hashline`, `adrkit`, `nats`, `skillfile`, `skillprism`) and 9 packaging pinned upstream release binaries (`tgrep`, `ck`, `fff-mcp`, `agent-mail`, `br`, `bd`, `bv`, `herdr`, `agentsync`)
- Pull requests build, test, and bottle on `macos-26` Apple Silicon via [`.github/workflows/tests.yml`](.github/workflows/tests.yml) and run isolated Bash 3.2 and Bash 5+ installer checks via [`tests/integration_agent_install.py`](tests/integration_agent_install.py)
- Bottles publish to GitHub Releases through [`.github/workflows/publish.yml`](.github/workflows/publish.yml), and daily upstream version checks run via [`.github/workflows/autobump.yml`](.github/workflows/autobump.yml)

## Topics for repo discovery

`homebrew` `homebrew-tap` `ai-agents` `coding-agents` `mcp` `mcp-server` `claude-code` `codex-cli` `antigravity-cli` `tree-sitter` `java-valhalla` `ast-grep` `ripwire` `tgrep` `hashline` `beads` `agent-mail` `adr` `agent-skills`

## Quick links

- [`README.md`](README.md) — install paths, per-formula usage, MCP registration tables, and skill directories
- [`AGENTS.md`](AGENTS.md) — tap maintenance rules for contributors and coding agents
- [`docs/agent-context.md`](docs/agent-context.md) — Valhalla grammar patch, autobump mechanics, bottle publishing, and workflow security
- [`tests/README.md`](tests/README.md) — isolated Bash 3.2 and Bash 5+ agent-installer integration suite
- [`scripts/autobump.sh`](scripts/autobump.sh) — `brew livecheck` URL and SHA-256 rewrite automation

## Authors

Artagon & Giedrius Trumpickas

## License

Tap scripts and formula definitions: MIT. Packaged tools are distributed under their respective upstream licenses (`MIT`, `Apache-2.0`, `MIT OR Apache-2.0`, or `MIT License with OpenAI/Anthropic Rider` installed at `$(brew --prefix <formula>)/LICENSE`); run `brew info artagon/aitools/<formula>` for per-formula license details.
