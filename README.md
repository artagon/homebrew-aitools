# Artagon AI Tools Homebrew Tap (`artagon/aitools`)

Curated high-performance developer tooling for AI coding agents.

```sh
# Tap this repository once:
brew tap artagon/aitools

# Code search, AST analysis, and hash-anchored editing:
brew install artagon/aitools/ripwire
brew install artagon/aitools/ast-grep-valhalla
brew install artagon/aitools/tree-sitter-java-valhalla
brew install artagon/aitools/tgrep
brew install artagon/aitools/ck
brew install artagon/aitools/fff-mcp
brew install artagon/aitools/hashline

# Multi-agent coordination, messaging, and Beads tracking:
brew install artagon/aitools/agent-mail
brew install artagon/aitools/br
brew install artagon/aitools/bd
brew install artagon/aitools/bv
brew install artagon/aitools/nats
brew install artagon/aitools/herdr

# Architecture decisions and agent skill/config management:
brew install artagon/aitools/adrkit
brew install artagon/aitools/agentsync
brew install artagon/aitools/skillfile
brew install artagon/aitools/skillprism

# Local agent memory, hybrid markdown search, and token compression:
brew install artagon/aitools/basic-memory
brew install artagon/aitools/hindsight
brew install artagon/aitools/qmd
brew install artagon/aitools/squeez
```

Use the qualified `artagon/aitools/<formula>` names to select this tap. Homebrew core also ships
same-named `tgrep`, `nats`, and `herdr` formulae, plus differently named formulae that install
overlapping binaries (`ast-grep`, `beads`, `beads_viewer`, and `adr-tools`; run
`brew unlink <formula>` first when one of those is already linked).
You can also install any formula directly without tapping first:

```sh
brew install artagon/aitools/ripwire
brew install artagon/aitools/hashline
```

On Apple Silicon with macOS 26 or later, the formulae install from bottles that the tap's CI
builds and publishes. Elsewhere, `tree-sitter-java-valhalla`, `ast-grep-valhalla`, `ripwire`,
`hashline`, `adrkit`, `nats`, `skillfile`, `skillprism`, `basic-memory`, `hindsight`, `qmd`, and
`squeez` build from source (`ast-grep-valhalla` and `ripwire` compile against
`artagon/aitools/tree-sitter-java-valhalla`, so Homebrew installs that grammar first). `tgrep`,
`ck`, `fff-mcp`, `agent-mail`, `br`, `bd`, `bv`, `herdr`, and `agentsync` install upstream release
binaries.

---

## JDK 28 Valhalla Java grammar

`artagon/aitools/tree-sitter-java-valhalla` patches tree-sitter-java 0.23.5, the grammar that
both ast-grep 0.51.1 and Ripwire 0.6.9 pin, to parse what the JDK 28 Valhalla `javac` accepts:

| Syntax | Example | Specification |
| :--- | :--- | :--- |
| Value classes and value records | `value record Point(int x, int y) {}` | JEP 401 (preview) |
| Statements before `super(...)` and `this(...)` | `this.x = x; super();` | JEP 513 |
| Module imports | `import module java.base;` | JEP 511 |
| Qualified record patterns | `o instanceof Shape.Circle(int r)` | JEP 440 |
| Annotations before a varargs ellipsis | `Object @Nullable ... rest` | JLS 8.4.1 |

`value` stays a contextual keyword: fields, methods, locals, enum constants, labels, and
annotation elements named `value` keep their upstream trees. For code without these forms the
patched grammar produces byte-identical trees. The upstream corpus and
`test/corpus/valhalla.txt` run in `brew test`.

The formula installs `libtree-sitter-java-valhalla` and the full grammar sources under
`$(brew --prefix tree-sitter-java-valhalla)/share/tree-sitter-java-valhalla`.

---

## ast-grep-valhalla

Builds [ast-grep 0.51.1](https://github.com/ast-grep/ast-grep/releases/tag/0.51.1) from source with
the Valhalla grammar compiled in as `java`. CLI patterns, `sgconfig.yml` rules, and the ast-grep
MCP server work without configuration changes.

It replaces Homebrew core's `ast-grep`, which installs the same `ast-grep` and `sg` binaries:

```sh
brew unlink ast-grep   # only when core ast-grep is installed
brew install artagon/aitools/ast-grep-valhalla
```

Core ast-grep cannot replace its built-in `java` parser from `sgconfig.yml`. To use the grammar
with it anyway, follow the `brew info artagon/aitools/tree-sitter-java-valhalla` caveats, which
register it under a custom language name.

---

## ripwire

Builds [Ripwire v0.6.9](https://github.com/redhat-et/ripwire/releases/tag/v0.6.9) — Codebase symbol maps and call graphs for AI agents — from source with the Valhalla Java grammar.
A query patch also indexes records, value records, compact constructors, and annotation
interfaces as Java definitions, which upstream 0.6.9 omits. Requires macOS 14 or later with
C++23 command-line tools, or Linux with a C++23 compiler. Linux builds are not yet verified by
this tap.

```sh
ripwire . --for="find the code that handles authentication"
```

Upgrade or uninstall:

```sh
brew upgrade ripwire
brew uninstall ripwire
```

### Optional agent integration

Ripwire skills and hooks are bundled under `$(brew --prefix ripwire)/share/ripwire/`.
Homebrew install and upgrade do not alter agent configurations or shell profiles automatically.

The tap provides `ripwire-agent-install` to manage skills and hooks across 6 AI agent CLIs:

| Agent CLI | Binary / Environment | Skills Target Path | Hook Support |
| :--- | :--- | :--- | :--- |
| **Claude Code** | `claude` / `~/.claude` | `~/.claude/skills` | `~/.claude/settings.json` |
| **OpenAI Codex** | `codex` / `~/.codex` | `${AGENTS_HOME:-$HOME/.agents}/skills` | `${CODEX_HOME:-$HOME/.codex}/hooks.json` |
| **Google Antigravity** | `agy` / `~/.gemini` / existing `AGY_SKILLS_DIR` | `${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}` | MCP server (`ripwire --mcp`) |
| **Moonshot Kimi** | `kimi` / `~/.kimi-code` | `${KIMI_CODE_HOME:-$HOME/.kimi-code}/skills` | MCP server (`ripwire --mcp`) |
| **Grok CLI** | `grok` / `~/.grok` | `${GROK_HOME:-$HOME/.grok}/skills` | MCP server (`ripwire --mcp`) |
| **GitHub Copilot** | `copilot` / `~/.copilot` | `${COPILOT_HOME:-$HOME/.copilot}/skills` | MCP server (`ripwire --mcp`) |
| **Cross-Agent Shared** | APM / multi-agent | `~/.agents/skills` | Standard discovery root |

### Quickstart (Auto-Detection)

To automatically detect installed CLIs and link skills:

```sh
ripwire-agent-install
```

An existing shared `~/.agents` directory alone does not identify a Codex installation.
If no agent is detected, activation installs shared skills without registering client hooks.
Both installers support stock macOS Bash 3.2.

Or from a local git checkout:

```sh
./scripts/install-agent-skills.sh
```

To list detected CLIs and target paths without modifying any files:

```sh
ripwire-agent-install --list
```

### Targeted Installation & Hooks

Activate skills and register optional advisory hooks for specific agents:

```sh
# Claude Code (skills + PreToolUse, SessionStart, and PromptRouter hooks)
brew install jq
ripwire-agent-install --claude --hook

# OpenAI Codex (skills + hooks)
ripwire-agent-install --codex --hook

# Antigravity, Kimi, Grok, and Copilot
ripwire-agent-install --agy --kimi --grok --copilot

# Cross-agent shared directory only
ripwire-agent-install --shared
```

`--hook` explicitly updates `~/.claude/settings.json` or `${CODEX_HOME:-$HOME/.codex}/hooks.json`. For Codex, review and trust the installed hooks through `/hooks`. Upstream hooks can record local usage metrics under `~/.ripwire`; review bundled hook scripts before enabling.

Rerun `ripwire-agent-install` after formula upgrades to refresh added, renamed, or retired skills.

### Manual / Upstream Activation

You can also invoke the upstream installer script directly:

```sh
# Claude Code
bash "$(brew --prefix ripwire)/share/ripwire/skills/install.sh" --claude

# Codex
bash "$(brew --prefix ripwire)/share/ripwire/skills/install.sh" --codex

# Custom directory
bash "$(brew --prefix ripwire)/share/ripwire/skills/install.sh" /path/to/skills
```

### Uninstallation

Uninstalling the formula does not alter agent configurations. To remove the integration:
1. Delete the symlinked `ripwire-*` directories and `.ripwire-manifest-v1` from the target agent's `skills` folder.
2. Remove any Ripwire hook stanzas from `~/.claude/settings.json` or `${CODEX_HOME:-$HOME/.codex}/hooks.json`.

---

## tgrep

Install [tgrep v1.2.6](https://github.com/microsoft/tgrep/releases/tag/v1.2.6) — Trigram-indexed grep with a client/server architecture for fast regex search in large codebases:

```sh
brew install artagon/aitools/tgrep
```

### Basic Usage

```sh
# Build trigram index into ./.tgrep
tgrep index .

# Start background search server (watches for file changes)
tgrep serve . &

# Instant indexed search (auto-connects to server)
tgrep "pattern" .

# Check index and server status
tgrep status .

# Search directly without index
tgrep --no-index "pattern" .
```

For AI coding agents (Claude, Codex, Antigravity, Kimi, Grok), see [tgrep AGENTS.md](https://github.com/microsoft/tgrep/blob/main/AGENTS.md).

---

## ck

Installs [ck 0.8.1](https://github.com/BeaconBay/ck/releases/tag/0.8.1) — local regex, BM25, and
semantic code search, with an MCP server (`ck --serve`). It keeps its index in a `.ck/` directory
next to the code.

```sh
ck --regex 'retry_failed_start' .
ck --lex 'failed server start' .
ck --hybrid 'where does the server retry a failed start' .
```

The first `--sem` or `--hybrid` search downloads an embedding model into
`${XDG_CACHE_HOME:-~/.cache}/ck/models`. The Intel macOS binary has no embedding support, so use
`--lex` or `--regex` there. Linux binaries need glibc 2.39 or newer. ck chunks code with tree-sitter
but has no Java grammar, so Java files are searched as plain-text chunks.

## fff-mcp

Installs [fff-mcp 0.11.0](https://github.com/dmtrKovalenko/fff/releases/tag/v0.11.0) — a fast,
frecency-ranked file search MCP server. Register `$(brew --prefix)/bin/fff-mcp` as a stdio MCP
server; pass `--no-update-check` to skip its startup update check and `--frecency-db <file>` to
rank by frecency. Requires macOS 13 or later.

Agent skills and `ck-agent-install` / `fff-agent-install` commands for both tools are planned in
the `artagon-scripts` change `add-artagon-ck-fff-search-plugins` and will ship as a formula revision.

---

## hashline

Builds [hashline v0.9.24](https://github.com/quangdang46/hashline/releases/tag/v0.9.24) (`MIT OR Apache-2.0`) from Rust source — hash-anchored line reading and patching for AI coding agents via CLI and stdio MCP server:

```sh
brew install artagon/aitools/hashline
```

This tap (`artagon/aitools`) is maintained by Artagon and is **not** an official `hashline` or Homebrew core distribution channel.

### Upgrade and configuration caveats

- Homebrew manages upgrades: run `brew upgrade artagon/aitools/hashline` (do **not** run `hashline update`).
- The installed wrapper sets `HASHLINE_NO_UPDATE_CHECK=1` to suppress upstream startup update checks.
- Installing, upgrading, or uninstalling this formula never modifies any agent configuration file.

### Bundled skill and confirmed agent skill directories

The formula installs a bundled `SKILL.md` directory at:

```sh
$(brew --prefix hashline)/share/hashline/skills/hashline
```

Copy or symlink that `hashline` directory into your agent's skill directory (`<name>` = `hashline` below). Confirmed skill paths from official provider documentation:

| Agent | Personal skill path | Project skill path |
| :--- | :--- | :--- |
| **Claude Code** | `~/.claude/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` |
| **OpenAI Codex** | `~/.agents/skills/<name>/SKILL.md` | `.agents/skills/<name>/SKILL.md` |
| **Google Antigravity CLI** | `${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}/<name>/SKILL.md` | `.agents/skills/<name>/SKILL.md` |

### MCP registration

Register the stable opt binary path `<path>` = `$(brew --prefix)/opt/hashline/bin/hashline` so upgrades do not break client configs:

| Client | Config file | Config key | Registration command or entry | Source |
| :--- | :--- | :--- | :--- | :--- |
| **Claude Code** | `~/.claude.json` | `mcpServers` | `claude mcp add hashline -- <path> mcp` | Provider docs + upstream `install.sh` (`4b7f8de`) |
| **OpenAI Codex** | `~/.codex/config.toml` | `mcp_servers.hashline` | `command = "<path>"`, `args = ["mcp"]` | Provider docs + upstream `install.sh` (`4b7f8de`) |
| **Google Antigravity CLI** | `~/.gemini/config/mcp_config.json` | `mcpServers` | `{"command": "<path>", "args": ["mcp"]}` | Provider docs |
| **Cursor** | `~/.cursor/mcp.json` | `mcpServers` | `{"command": "<path>", "args": ["mcp"]}` | Upstream `install.sh` (`4b7f8de`) |
| **Windsurf** | `~/.codeium/windsurf/mcp_config.json` | `mcpServers` | `{"command": "<path>", "args": ["mcp"]}` | Upstream `install.sh` (`4b7f8de`) |
| **VS Code** | `.vscode/mcp.json` | `servers` | `{"command": "<path>", "args": ["mcp"]}` | Upstream `install.sh` (`4b7f8de`) |
| **Gemini CLI** | `~/.gemini/settings.json` | `mcpServers` | `{"command": "<path>", "args": ["mcp"]}` | Upstream `install.sh` (`4b7f8de`) |
| **Amp** | `~/.config/amp/settings.json` | `amp.mcpServers` | `{"command": "<path>", "args": ["mcp"]}` | Upstream `install.sh` (`4b7f8de`) |
| **Droid** | `~/.factory/mcp.json` | `mcpServers` | `{"command": "<path>", "args": ["mcp"]}` | Upstream `install.sh` (`4b7f8de`) |
| **OpenCode** | `~/.config/opencode/opencode.json` | `mcp.servers` | `{"type": "local", "command": ["<path>", "mcp"]}` | Upstream `install.sh` (`4b7f8de`) |

Host plugins (`pi install npm:hashline-pi` and `npm i hashline-opencode-plugin`) resolve `hashline` directly from `PATH`.

---

## agent-mail

Installs [mcp_agent_mail_rust](https://github.com/Dicklesworthstone/mcp_agent_mail_rust) `0.3.40` prebuilt release binaries for multi-agent mail, thread coordination, and file reservations:

```sh
brew install artagon/aitools/agent-mail
```

Provides both `mcp-agent-mail` (register `$(brew --prefix)/opt/agent-mail/bin/mcp-agent-mail` as a stdio MCP server) and `am` (CLI and local HTTP server via `am serve-http`). Distributed under the `MIT License with OpenAI/Anthropic Rider` (`license :cannot_represent` in Homebrew); the full license text is installed at `$(brew --prefix agent-mail)/LICENSE`.

## br

Installs [beads_rust](https://github.com/Dicklesworthstone/beads_rust) `0.7.6` prebuilt release binaries — the Rust `br` issue-tracker CLI with shell completions:

```sh
brew install artagon/aitools/br
```

Distributed under the `MIT License with OpenAI/Anthropic Rider` (`license :cannot_represent`); the full license text is installed at `$(brew --prefix br)/LICENSE`.

## bd

Installs [beads](https://github.com/gastownhall/beads) `1.3.4` (`MIT`) prebuilt release binaries — the `bd` distributed graph issue tracker built with the pure-Go embedded Dolt store, plus shell completions. It conflicts with `beads`, which installs the same `bd` binary:

```sh
brew unlink beads   # only when beads is installed
brew install artagon/aitools/bd
```

## bv

Installs [beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) `0.26.0` prebuilt release binaries — the `bv` terminal UI and `--robot-*` graph triage CLI for Beads repositories. It conflicts with `beads_viewer`, which installs the same `bv` binary:

```sh
brew unlink beads_viewer   # only when beads_viewer is installed
brew install artagon/aitools/bv
```

Upgrade through Homebrew (`brew upgrade artagon/aitools/bv`); do **not** run `bv --update`. Distributed under the `MIT License with OpenAI/Anthropic Rider` (`license :cannot_represent`); the full license text is installed at `$(brew --prefix bv)/LICENSE`.

## adrkit

Builds [adrkit](https://github.com/mbeacom/adrkit) `0.20.0` (`Apache-2.0`) from source (`bun` build targeting the `node` runtime), installing `adr`, `adrkit`, and the stdio MCP server `adrkit-mcp` (`$(brew --prefix)/opt/adrkit/bin/adrkit-mcp`). Bundled agent skills are installed under `$(brew --prefix adrkit)/share/adrkit/skills`. It conflicts with Homebrew core's `adr-tools`, which also installs `adr`:

```sh
brew unlink adr-tools   # only when core adr-tools is installed
brew install artagon/aitools/adrkit
```

## nats

Builds [natscli](https://github.com/nats-io/natscli) `0.5.1` (`Apache-2.0`) from Go source with bash and zsh completions. Use the qualified tap name because Homebrew core also has a `nats` formula:

```sh
brew install artagon/aitools/nats
```

## herdr

Installs [herdr](https://github.com/herdrdev/herdr) `0.9.5` (`Apache-2.0`) prebuilt release binaries, shell completions, and `LICENSE`. Use the qualified tap name because Homebrew core also has a `herdr` formula:

```sh
brew install artagon/aitools/herdr
```

## agentsync

Installs [agentsync](https://github.com/dallay/agentsync) `1.53.1` (`MIT`) prebuilt release binaries to synchronize agent rules, skills, and MCP configurations across coding clients:

```sh
brew install artagon/aitools/agentsync
```

The installed wrapper sets `AGENTSYNC_NO_UPDATE_CHECK=1`; upgrade with `brew upgrade artagon/aitools/agentsync`.

## skillfile

Builds [skillfile](https://github.com/eljulians/skillfile) `1.9.2` (`Apache-2.0`) from Rust source with shell completions:

```sh
brew install artagon/aitools/skillfile
```

The installed wrapper sets `SKILLFILE_NO_UPDATE_NOTIFIER=1`; upgrade with `brew upgrade artagon/aitools/skillfile`.

## skillprism

Builds [skillprism](https://github.com/Tuvren/skillprism) `0.5.0` (`Apache-2.0`) from Rust source with shell completions and a man page:

```sh
brew install artagon/aitools/skillprism
```

---

## basic-memory

Builds [basic-memory](https://github.com/basicmachines-co/basic-memory) `1.0.0` (`AGPL-3.0-or-later`) from source via `uv` (Python 3.13) — local-first Zettelkasten knowledge graph and stdio JSON-RPC MCP server (`basic-memory` and `bm`) with bundled `memory-*` agent skills:

```sh
brew install artagon/aitools/basic-memory
```

Hardened local-only defaults enforced by the installed wrappers:
- **Local stdio JSON-RPC only**: `cloud`, `--transport streamable-http`, and `--transport sse` are disabled (`BASIC_MEMORY_FORCE_LOCAL=true`, `BASIC_MEMORY_EXPLICIT_ROUTING=true`).
- **No background self-updates or telemetry**: sets `BASIC_MEMORY_AUTO_UPDATE=false`, `BASIC_MEMORY_NO_PROMOS=1`, `BASIC_MEMORY_CLOUD_PROMO_OPT_OUT=true`, and `BASIC_MEMORY_LOGFIRE_ENABLED=false`; blocks `basic-memory update` / `bm update` (use `brew upgrade artagon/aitools/basic-memory`).
- Register the stdio MCP server with `$(brew --prefix)/opt/basic-memory/bin/basic-memory mcp`; bundled skills are installed under `$(brew --prefix basic-memory)/share/basic-memory/skills`.

## hindsight

Builds [hindsight](https://github.com/vectorize-io/hindsight) `1.2.1` (`MIT`) from source — installing the `hindsight` Rust CLI (`1.2.1`), the `hindsight-mcp` stdio JSON-RPC MCP server and `hindsight-coding-agents` bundle (`0.8.7`), and bundled skills under `$(brew --prefix hindsight)/share/hindsight/skills`:

```sh
brew install artagon/aitools/hindsight
```

Hardened loopback-only defaults enforced at compile time and in wrappers:
- **Loopback HTTP + stdio JSON-RPC only**: defaults to `http://127.0.0.1:8888` (`serverMode: "self-hosted"`) and rejects Hindsight Cloud (`--server cloud`) and any `HINDSIGHT_API_URL` / `apiUrl` outside `127.0.0.1`, `::1`, or `localhost`.
- **No self-updates**: `autoUpdate` is compiled to `false` and `hindsight-coding-agents update` is disabled (use `brew upgrade artagon/aitools/hindsight`).
- Register the stdio MCP server with `HINDSIGHT_MCP_HARNESS=claude-code $(brew --prefix)/opt/hindsight/bin/hindsight-mcp`.

## qmd

Builds Tobi Lütke's [qmd](https://github.com/tobi/qmd) `2.8.3` (`MIT`) from source — on-device hybrid BM25 full-text search, `sqlite-vec` vector search, and local GGUF LLM reranking for Markdown knowledge bases, with CLI (`qmd`), stdio/loopback MCP server (`qmd mcp`), and bundled skill (`$(brew --prefix qmd)/share/qmd/skills/qmd`):

```sh
brew install artagon/aitools/qmd
```

First `qmd embed` or `qmd query` run downloads local GGUF models into `~/.cache/qmd`. Register `$(brew --prefix)/opt/qmd/bin/qmd mcp` as a local stdio MCP server.

## squeez

Builds [squeez](https://github.com/claudioemmanuel/squeez) `1.49.3` (`Apache-2.0`) from Rust source — token compressor CLI and read-only stdio JSON-RPC MCP server (`squeez mcp`):

```sh
brew install artagon/aitools/squeez
```

Hardened conservative defaults compiled into this build (without modifying `~/.claude`):
- `auto_compress_md = false`
- `persona = off`
- `wrap_bash = false`
- `squeez update` is disabled; upgrade via `brew upgrade artagon/aitools/squeez`.
- Register the stdio MCP server with `$(brew --prefix)/opt/squeez/bin/squeez mcp`.

---

## Automatic version updates

[`autobump.yml`](.github/workflows/autobump.yml) runs daily and on demand. Each formula's
`livecheck` block finds the latest upstream release, and
[`scripts/autobump.sh`](scripts/autobump.sh) opens one pull request per new version. The script
moves every versioned URL to the new release and recomputes its SHA-256, so tgrep's per-platform
archives bump the same way as single-archive formulae. A `tree-sitter-java-valhalla` bump also
bumps the `revision` of `ast-grep-valhalla` and `ripwire`, which compile the grammar in.

## Bottles and publishing

Every pull request runs [`tests.yml`](.github/workflows/tests.yml): `brew test-bot` builds, tests,
and bottles the changed formulae on a macOS 26 Apple Silicon runner, runs the provenance and
installer suites, and generates SPDX 2.3 and CycloneDX SBOMs plus a `build-manifest.json` pinned
to the pull request head commit. When it passes, review the diff and publish the commit you
reviewed:

```sh
gh workflow run publish.yml -f pull_request=<number> \
  -f head_sha="$(gh pr view <number> --json headRefOid --jq .headRefOid)"
```

Publishing runs only from `main` and refuses pull requests from forks, pull requests behind
`main`, pull requests modifying `.github/workflows/` (unless `allow_workflow_changes=true` is
explicitly supplied after auditing workflow diffs), a head other than the reviewed commit, and
commits whose newest test run failed.

[`publish.yml`](.github/workflows/publish.yml) separates staging, OIDC signing, and publishing:

1. `stage-bottles` (`contents: read`) verifies the `bottles_macos-26` and `provenance_macos-26`
   artifact digests, runs `brew pr-pull --no-upload`, and merges `bottle do` blocks locally.
2. [`sign-bottles.yml`](.github/workflows/sign-bottles.yml) mints SLSA v1 and `bottle-lineage/v1`
   attestations, signs Sigstore `cosign` v3 bundles, self-verifies online and offline, and uploads
   bottles and provenance sidecars to draft GitHub Releases (`<formula>-<pkg_version>`).
3. `push-main` verifies that only `bottle do ... end` lines changed relative to `head_sha`, pushes
   `main`, publishes the draft releases, and verifies every bottle with `brew verify`.

Do not merge formula pull requests directly; the formulae would ship without bottles or
attestations. To backfill or refresh provenance sidecars on already-published releases from `main`:

```sh
gh workflow run attest.yml
gh workflow run attest.yml -f formulae="ripwire ast-grep-valhalla"
```

Bump pull requests follow the same path; `scripts/autobump.sh` dispatches `tests.yml` on each one.
A bump fails on purpose when:

- the grammar patch or Ripwire's query patch no longer applies;
- ast-grep pins a tree-sitter-java version that the patched crate cannot replace; or
- Ripwire changes its bundled installer or skills, which `tests/integration_agent_install.py` pins.

One-time repository setting: in Settings → Actions → General, allow GitHub Actions to create and
approve pull requests. To check or apply bumps locally:

```sh
scripts/autobump.sh check
scripts/autobump.sh write tgrep
```

## Build provenance and verification

Published bottles ship with cryptographic build provenance attested by
[`.github/workflows/sign-bottles.yml`](.github/workflows/sign-bottles.yml) on `refs/heads/main`.
Each GitHub Release (`<formula>-<pkg_version>`) carries the bottle tarball and 8 sidecars:

| Asset suffix | Format | Purpose |
| :--- | :--- | :--- |
| `.sha256` | `shasum -a 256` | Bottle SHA-256 checksum matching `Formula/<name>.rb` |
| `.intoto.jsonl` | Sigstore bundle (JSONL) | SLSA v1 build provenance binding both `--` and `-` bottle filenames |
| `.lineage.intoto.jsonl` | Sigstore bundle (JSONL) | Signed `bottle-lineage/v1` predicate binding builder run and SBOM SHA-256 digests |
| `.sigstore.json` | Sigstore v0.3 bundle | Keyless `cosign` v3 blob signature (`Fulcio` + `Rekor`) |
| `.spdx.json` | SPDX 2.3 JSON | Bottle archive SBOM generated by Anchore `syft` |
| `.spdx.sigstore.json` | Sigstore v0.3 DSSE bundle | Keyless `cosign` v3 SPDX attestation embedding `.spdx.json` |
| `.cdx.json` | CycloneDX 1.6 JSON | Bottle archive SBOM in CycloneDX format |
| `.provenance.json` | JSON | Human-readable summary of builder run, commit SHAs, and asset digests |

### Published bottle versions, certificates, and provenance proofs

<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->
<!-- Auto-generated from Formula/*.rb by scripts/update-readme-bottles.sh (and refreshed automatically by publish.yml). Do not edit manually. -->

All published bottles are attested on `refs/heads/main` and indexed in the [GitHub Attestations transparency log](https://github.com/artagon/homebrew-aitools/attestations).

| Formula | Bottle (`arm64_tahoe`) | Bottle & SHA-256 | Provenance Certificates & Proofs | Signed SBOMs |
| :--- | :--- | :--- | :--- | :--- |
| [`adrkit`](Formula/adrkit.rb) | `0.20.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/adrkit-0.20.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz) · [`345413cfc7e6…`](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:345413cfc7e64a2352710e60f6d93d8a39409966323ddb0753e3bf58e86c3c26) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/adrkit-0.20.0/adrkit-0.20.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`agent-mail`](Formula/agent-mail.rb) | `0.3.40` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/agent-mail-0.3.40) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz) · [`2dcff69a3a2a…`](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:2dcff69a3a2ac74e215f4f74bec75ad93e4124ce0e99f8de213abbb85721179f) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`agentsync`](Formula/agentsync.rb) | `1.53.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/agentsync-1.53.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz) · [`a7ac20920d6d…`](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:a7ac20920d6d1edbdb7d93d91db75f9fe113c285cf393309eb5fbd78d017de37) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`ast-grep-valhalla`](Formula/ast-grep-valhalla.rb) | `0.51.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ast-grep-valhalla-0.51.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz) · [`799751736029…`](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:7997517360295ece709fc010bda6605a90ed88551ac1e8982553d60358def68f) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.1/ast-grep-valhalla-0.51.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`bd`](Formula/bd.rb) | `1.3.4` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/bd-1.3.4) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz) · [`c6f3d9bdcb50…`](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:c6f3d9bdcb5041c9ece17e6b11dacbde40b46d5ef86b1199167f47056d9b0235) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`br`](Formula/br.rb) | `0.7.6` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/br-0.7.6) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz) · [`e79478b19802…`](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:e79478b198025358c79c6dc57d6f13c384bcc3ded7f1076aafb19978e3ea38c6) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`bv`](Formula/bv.rb) | `0.26.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/bv-0.26.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz) · [`949c3e637953…`](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:949c3e637953729383216d0af65738b4918120332f1190caf0c321c4e81d6eb3) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`ck`](Formula/ck.rb) | `0.8.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ck-0.8.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz) · [`5f2e284ae568…`](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:5f2e284ae5689eab88e4ba9028e3cc43651d81b7a301b5b91cd5e71fc3c47630) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`fff-mcp`](Formula/fff-mcp.rb) | `0.11.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/fff-mcp-0.11.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz) · [`b4e95d364d63…`](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:b4e95d364d63360fdb85a30b2575c039f5d65754ca12ec0fe555d393d2901719) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`hashline`](Formula/hashline.rb) | `0.9.24` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/hashline-0.9.24) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz) · [`458689231f7f…`](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:458689231f7f42afa5575edfce9d06d49911cd8064019befdbc928a1c28c9914) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`herdr`](Formula/herdr.rb) | `0.9.5` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/herdr-0.9.5) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz) · [`4dfdf6be14ea…`](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:4dfdf6be14ea11c985bda408b1d946552e6a048e661e26c844df4fffd16a28c3) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`nats`](Formula/nats.rb) | `0.5.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/nats-0.5.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz) · [`7b52481a53a5…`](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:7b52481a53a5987e4b68941e3c3d27afe9f7f1d51fc4294e67c473a72b740fa1) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`ripwire`](Formula/ripwire.rb) | `0.6.9` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ripwire-0.6.9) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz) · [`14aac113c56d…`](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:14aac113c56d132059a574d74c5f170f9f737edddfe7e1431c53dff1246caf77) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.9/ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`skillfile`](Formula/skillfile.rb) | `1.9.2` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/skillfile-1.9.2) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz) · [`e7241c41a16a…`](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:e7241c41a16a3dab3fcbf0e8e98a805906c7e2fa61fc2dfac7aac6c4f07673db) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`skillprism`](Formula/skillprism.rb) | `0.5.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/skillprism-0.5.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz) · [`bc2d0a115955…`](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:bc2d0a11595523e14ffd7ae94202485d47ba5199355f9febfb3f32a68c24fd56) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`tgrep`](Formula/tgrep.rb) | `1.2.6` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/tgrep-1.2.6) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz) · [`4290a043e68e…`](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:4290a043e68ef888507a70faaa84cec3b5540735f48e8c1c16821ed85540d228) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6/tgrep-1.2.6.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`tree-sitter-java-valhalla`](Formula/tree-sitter-java-valhalla.rb) | `0.23.5` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/tree-sitter-java-valhalla-0.23.5) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz) · [`3090dc558d97…`](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:3090dc558d979c821fc9da23d2fc5a00e4143c5f33fec80c53ba63c9c1755109) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.cdx.json) |
<!-- END BOTTLE_PROVENANCE_TABLE -->

### 1. Native Homebrew verification

Enable Homebrew's built-in attestation verification (requires `gh` authenticated to `github.com`
or `HOMEBREW_GITHUB_API_TOKEN`):

```sh
HOMEBREW_VERIFY_ATTESTATIONS=1 brew install artagon/aitools/ripwire
brew verify --bottle-tag=arm64_tahoe artagon/aitools/ripwire
```

### 2. Strict multi-layer & air-gapped verification (`scripts/verify-provenance.sh`)

Homebrew's `brew verify` checks repository-level attestation origin (`--repo artagon/homebrew-aitools`).
[`scripts/verify-provenance.sh`](scripts/verify-provenance.sh) additionally enforces the exact
signer SAN (`...@refs/heads/main`), `--source-ref refs/heads/main`, `--deny-self-hosted-runners`,
atomic `--` + `-` dual-subject binding, signed `bottle-lineage/v1` SBOM digests, and Sigstore
`cosign` v3 bundles:

```sh
# Online check for one formula or the entire tap:
./scripts/verify-provenance.sh ripwire
./scripts/verify-provenance.sh --all --require-cosign --homebrew

# Save bundles + trusted root once, then verify strictly offline (air-gapped):
./scripts/verify-provenance.sh --save-bundles ./bundles ripwire
./scripts/verify-provenance.sh --offline \
  --bundle-dir ./bundles \
  --trusted-root ./bundles/trusted_root.jsonl \
  --require-cosign \
  ripwire
```

### 3. Direct CLI verification (`gh` and `cosign`)

```sh
# GitHub CLI (SLSA v1 provenance, ref-bound to sign-bottles.yml@refs/heads/main):
gh attestation verify ripwire-0.6.9.arm64_tahoe.bottle.tar.gz \
  --repo artagon/homebrew-aitools \
  --cert-identity "https://github.com/artagon/homebrew-aitools/.github/workflows/sign-bottles.yml@refs/heads/main" \
  --source-ref "refs/heads/main" \
  --deny-self-hosted-runners

# Sigstore cosign v3 (blob signature + SPDX attestation):
cosign verify-blob \
  --bundle ripwire-0.6.9.arm64_tahoe.bottle.tar.gz.sigstore.json \
  --certificate-identity "https://github.com/artagon/homebrew-aitools/.github/workflows/sign-bottles.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ripwire-0.6.9.arm64_tahoe.bottle.tar.gz
```

**Scope & SBOM coverage notes**:
- Source-built formulae (`tree-sitter-java-valhalla`, `ast-grep-valhalla`, `ripwire`, `hashline`,
  `adrkit`, `nats`, `skillfile`, `skillprism`) attest compilation in `tests.yml` on GitHub-hosted
  `macos-26` runners; upstream-binary formulae (`tgrep`, `ck`, `fff-mcp`, `agent-mail`, `br`, `bd`,
  `bv`, `herdr`, `agentsync`) attest bottle packaging of the SHA-256-pinned upstream release asset.
- Go binaries (`bd`, `bv`, `nats`, `tgrep`) and `cargo-auditable` Rust binaries expose full
  compiled module inventories to `syft`, whereas standard Rust/C/C++ binaries without embedded
  audit metadata and `adrkit` (`bun` single-file JS bundle) expose bottle archive and manifest
  files only.

## Validation

See [integration and provenance tests](tests/README.md) for isolated checks under stock macOS
`/bin/bash` 3.2 and modern Bash 5+:
- `tests/integration_agent_install.py` exercises both Ripwire activation entrypoints and opt-in
  hook registration against the real bundled payload in temporary agent homes.
- `tests/test_verify_provenance.py` exercises `scripts/verify-provenance.sh` across all 17 live
  formulae, online and air-gapped offline bundles, tamper rejection, and isolated `--homebrew`
  verification without touching live user state.
