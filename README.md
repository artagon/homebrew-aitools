# Artagon AI Tools Homebrew Tap (`artagon/aitools`)

Curated developer tooling, MCP servers, local memory graphs, and Valhalla-aware AST analyzers for AI coding agents, published with SLSA v1, signed lineage, Sigstore `cosign` v3, and SPDX/CycloneDX SBOM provenance.

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

# Local agent memory, hybrid Markdown search, and token compression:
brew install artagon/aitools/basic-memory
brew install artagon/aitools/hindsight
brew install artagon/aitools/qmd
brew install artagon/aitools/squeez

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
```

Use the fully qualified `artagon/aitools/<formula>` names to select this tap. Homebrew core also ships same-named `tgrep`, `nats`, and `herdr` formulae, plus differently named formulae that install overlapping binaries (`ast-grep`, `beads`, `beads_viewer`, and `adr-tools`; run `brew unlink <formula>` first when one of those is already linked). Installing, upgrading, or uninstalling any formula in this tap **never** modifies live user agent configuration files (`~/.claude`, `~/.codex`, `~/.gemini`, `~/.config`, etc.).

---

## Tap Project Catalog, Build Defaults, and Config Defaults

Every formula in `artagon/aitools` is listed below with links to its tap formula, upstream repository, tap build defaults, and tap runtime/configuration defaults:

| Tap Formula | Upstream Project & License | Description | Build Defaults in Tap | Config & Runtime Defaults in Tap |
| :--- | :--- | :--- | :--- | :--- |
| [`tree-sitter-java-valhalla`](Formula/tree-sitter-java-valhalla.rb) | [tree-sitter/tree-sitter-java](https://github.com/tree-sitter/tree-sitter-java) (`MIT`) | Tree-sitter Java grammar extended for JDK 28 Valhalla (`value` classes/records, JEP 401/440/511/513) | Source build (`tree-sitter generate --abi 14` + C11 `-O2 -fPIC -shared`); additive Valhalla grammar patch; installs `libtree-sitter-java-valhalla` + crate sources in `pkgshare` | Contextual `value` keyword preserves upstream parse trees for standard Java;opt-in `customLanguages` registration for external `ast-grep` |
| [`ast-grep-valhalla`](Formula/ast-grep-valhalla.rb) | [ast-grep/ast-grep](https://github.com/ast-grep/ast-grep) (`MIT`) | Structural AST code search, linting, rewriting, and MCP server with Valhalla Java built in | Source build (`cargo install --locked`, `crates/cli`) patching `tree-sitter-java` to `tree-sitter-java-valhalla`; generates `bash`/`zsh`/`fish`/`pwsh` completions; installs `ast-grep` & `sg` (`conflicts_with "ast-grep"`) | Built-in `java` language uses Valhalla grammar with zero `sgconfig.yml` changes; no startup telemetry or config writes |
| [`ripwire`](Formula/ripwire.rb) | [redhat-et/ripwire](https://github.com/redhat-et/ripwire) (`Apache-2.0`) | Codebase symbol maps, call graphs, blast-radius queries, and MCP server for AI agents | Source build (CMake + C++23) with `tree-sitter-java-valhalla` `parser.c` + Java query patch (records, value records, compact constructors, `@interface`); installs `ripwire`, `ripwire-agent-install`, and bundled `pkgshare` skills/hooks | No automatic skill or hook activation on `brew install`; `ripwire-agent-install` requires explicit `--hook` before touching Claude/Codex configs |
| [`tgrep`](Formula/tgrep.rb) | [microsoft/tgrep](https://github.com/microsoft/tgrep) (`MIT`) | Trigram-indexed regex search CLI and background watcher daemon for large repositories | SHA-256-pinned upstream release binary (`aarch64`/`x86_64` macOS & Linux musl); installs `tgrep` and `README.md` | Local `.tgrep/` repository index only; no background service started automatically on install |
| [`ck`](Formula/ck.rb) | [BeaconBay/ck](https://github.com/BeaconBay/ck) (`MIT OR Apache-2.0`) | Local regex, BM25 lexical, and semantic hybrid code search CLI + MCP server (`ck --serve`) | SHA-256-pinned upstream release binary (checks `glibc >= 2.39` on Linux); installs `ck`, docs, and `LICENSE-MIT` / `LICENSE-APACHE` | Local `.ck/` index; `--lex` and `--regex` run offline; first `--sem`/`--hybrid` caches ONNX model in `${XDG_CACHE_HOME:-~/.cache}/ck/models` |
| [`fff-mcp`](Formula/fff-mcp.rb) | [dmtrKovalenko/fff](https://github.com/dmtrKovalenko/fff) (`MIT`) | Fast frecency-ranked fuzzy file search and grep stdio MCP server | SHA-256-pinned upstream release binary (`macos >= :ventura`) + pinned tag `LICENSE` resource; installs `fff-mcp` | Stdio MCP server; pass `--no-update-check` in client MCP args to skip upstream startup update checks |
| [`hashline`](Formula/hashline.rb) | [quangdang46/hashline](https://github.com/quangdang46/hashline) (`MIT OR Apache-2.0`) | Hash-anchored line reading and deterministic file patching CLI + stdio MCP server | Source build (`cargo install --locked`, `crates/core` into `libexec`); installs `hashline` wrapper and bundled `pkgshare/skills/hashline/SKILL.md` | Wrapper exports `HASHLINE_NO_UPDATE_CHECK=1`; upgrades managed via Homebrew (`hashline update` discouraged); zero agent config mutation |
| [`basic-memory`](Formula/basic-memory.rb) | [basicmachines-co/basic-memory](https://github.com/basicmachines-co/basic-memory) (`AGPL-3.0-or-later`) | Local-first Markdown Zettelkasten knowledge graph CLI (`basic-memory`, `bm`) and stdio MCP server | Source build via `uv` (managed Python `3.13`, `--no-cache`, `preserve_rpath`); installs `basic-memory`, `bm`, and `pkgshare/skills/memory-*` | **Local stdio JSON-RPC only**: exports `BASIC_MEMORY_FORCE_LOCAL=true`, `BASIC_MEMORY_EXPLICIT_ROUTING=true`, `BASIC_MEMORY_AUTO_UPDATE=false`, `BASIC_MEMORY_NO_PROMOS=1`, `BASIC_MEMORY_CLOUD_PROMO_OPT_OUT=true`, `BASIC_MEMORY_LOGFIRE_ENABLED=false`; blocks `cloud`, `--cloud`, `update`, and `streamable-http`/`sse` transports |
| [`hindsight`](Formula/hindsight.rb) | [vectorize-io/hindsight](https://github.com/vectorize-io/hindsight) (`MIT`) | Semantic agent memory CLI (`hindsight`), stdio MCP server (`hindsight-mcp`), and agent harness installer (`hindsight-coding-agents`) | Source build: Rust `hindsight-cli` (`cargo install --locked`) + Node/TypeScript `coding-agents` bundle (`npm ci --ignore-scripts && npm run build`); installs 5 skill sets in `pkgshare/skills` | **Loopback HTTP + stdio JSON-RPC only**: compiled defaults `apiUrl=http://127.0.0.1:8888`, `serverMode="self-hosted"`, `autoUpdate=false`; removes Cloud from installer choices, rejects non-loopback URLs (`127.0.0.1`, `::1`, `localhost` only) and `update`, and requires explicit `HINDSIGHT_MCP_HARNESS` |
| [`qmd`](Formula/qmd.rb) | [tobi/qmd](https://github.com/tobi/qmd) (`MIT`) | Tobi Lütke's Query Markup Documents — on-device BM25 + `sqlite-vec` + GGUF reranking search CLI & MCP server | Source build (`npm run build` + `std_npm_args`, pruning non-native `prebuilds/*` addons and lockfiles to bind Homebrew `node`); installs `qmd` and `pkgshare/skills/qmd` | Wrapper exports `QMD_SOURCE_MODE=0`; local SQLite index + stdio (`qmd mcp`) or loopback (`localhost:8181`) MCP; GGUF models download on first `embed`/`query` to `~/.cache/qmd` |
| [`squeez`](Formula/squeez.rb) | [claudioemmanuel/squeez](https://github.com/claudioemmanuel/squeez) (`Apache-2.0`) | Token-saving CLI output compressor and read-only stdio JSON-RPC MCP server (`squeez mcp`) | Source build (`cargo install --locked --bin squeez`) with source patches on `config.rs`, `persona.rs`, and `setup.rs`; installs `squeez` and `NOTICE` | **Conservative defaults** (both unconfigured and in `squeez setup` `config.ini`): `auto_compress_md=false`, `persona=off`, `wrap_bash=false`; wrapper blocks `squeez update` |
| [`agent-mail`](Formula/agent-mail.rb) | [Dicklesworthstone/mcp_agent_mail_rust](https://github.com/Dicklesworthstone/mcp_agent_mail_rust) (`:cannot_represent` — MIT + Rider) | Multi-agent asynchronous mail, thread summaries, and advisory file-reservation MCP server & CLI | SHA-256-pinned upstream release archive; installs `mcp-agent-mail`, `am`, `README.md`, and full custom `LICENSE` in `prefix` | Local stdio (`mcp-agent-mail`) or local HTTP (`am serve-http`); caveats warn against `am self-update`; zero agent config writes |
| [`br`](Formula/br.rb) | [Dicklesworthstone/beads_rust](https://github.com/Dicklesworthstone/beads_rust) (`:cannot_represent` — MIT + Rider) | Fast Rust local-first graph issue tracker (`br`) for AI coding agents | SHA-256-pinned upstream release archive; generates `bash`/`zsh`/`fish` completions; installs `br` and full custom `LICENSE` in `prefix` | Local `.beads/` repository state only; caveats warn against `br upgrade` |
| [`bd`](Formula/bd.rb) | [gastownhall/beads](https://github.com/gastownhall/beads) (`MIT`) | Distributed Git-backed graph issue tracker (`bd`) with embedded pure-Go Dolt store | SHA-256-pinned upstream release archive built with `BD_DISABLE_METRICS=1` during completion generation; installs `bd`, `LICENSE`, and completions (`conflicts_with "beads"`) | No external Dolt server required; set `BD_DISABLE_METRICS=1` or run `bd metrics off` at runtime to opt out of upstream telemetry |
| [`bv`](Formula/bv.rb) | [Dicklesworthstone/beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) (`:cannot_represent` — MIT + Rider) | Graph-aware terminal UI and `--robot-*` JSON triage engine for Beads repositories | SHA-256-pinned upstream release archive; generates Cobra shell completions; installs `bv` and full custom `LICENSE` (`conflicts_with "beads_viewer"`) | Read-only graph analysis over `.beads/`; caveats warn against `bv --update` |
| [`adrkit`](Formula/adrkit.rb) | [mbeacom/adrkit](https://github.com/mbeacom/adrkit) (`Apache-2.0`) | Architecture Decision Record (ADR) authoring, linting, and stdio MCP governance server | Source build (`bun install --frozen-lockfile --ignore-scripts` + `bun build --target=node`); wrappers pin Homebrew `node`; installs `adr`, `adrkit`, `adrkit-mcp`, completions, and `pkgshare/skills` (`conflicts_with "adr-tools"`) | Defaults to `docs/adr` inside a Git worktree (`--cwd` / `--dir` override); zero agent config mutation |
| [`nats`](Formula/nats.rb) | [nats-io/natscli](https://github.com/nats-io/natscli) (`Apache-2.0`) | Official NATS JetStream, KV, and pub/sub CLI for agent event buses | Source build (`go build` with `-s -w -X main.version=...`); generates `bash` and `zsh` completions; installs `nats` | Stores named contexts under `${XDG_CONFIG_HOME:-~/.config}/nats/context`; no background daemon started |
| [`herdr`](Formula/herdr.rb) | [herdrdev/herdr](https://github.com/herdrdev/herdr) (`Apache-2.0`) | Multiplexed terminal workspace and session manager for AI coding agents | SHA-256-pinned upstream release binary + pinned tag `LICENSE` resource; generates shell completions; installs `herdr` | Local Unix socket & XDG config (`HERDR_CONFIG_PATH`, `HERDR_SOCKET_PATH`); caveats warn against `herdr update` |
| [`agentsync`](Formula/agentsync.rb) | [dallay/agentsync](https://github.com/dallay/agentsync) (`MIT`) | Symlink-based synchronizer for AI agent rules, skills, and MCP server definitions | SHA-256-pinned upstream release archive into `libexec` with env wrapper in `bin/agentsync`; installs `README.md` and `LICENSE` | Wrapper exports `AGENTSYNC_NO_UPDATE_CHECK=1`; modifies `.agents/agentsync.toml` only when explicitly invoked |
| [`skillfile`](Formula/skillfile.rb) | [eljulians/skillfile](https://github.com/eljulians/skillfile) (`Apache-2.0`) | Declarative `Skillfile` manifest validator and installer for AI agent skills | Source build (`cargo install --locked`, `crates/cli` into `libexec`); generates shell completions; installs `skillfile` wrapper | Wrapper exports `SKILLFILE_NO_UPDATE_NOTIFIER=1`; upgrades managed via Homebrew |
| [`skillprism`](Formula/skillprism.rb) | [Tuvren/skillprism](https://github.com/Tuvren/skillprism) (`Apache-2.0`) | Jinja2-style multi-harness skill template compiler (`SKILL.md.j2` -> per-agent `dist/`) | Source build (`cargo install --locked`); generates shell completions and `man1/skillprism.1` man page | Pure local compiler reading `skillprism.yaml` into `./dist/`; no network calls or live agent config edits |

---

## JDK 28 Valhalla Java grammar (`tree-sitter-java-valhalla`)

- **Tap formula**: [`Formula/tree-sitter-java-valhalla.rb`](Formula/tree-sitter-java-valhalla.rb) (`brew install artagon/aitools/tree-sitter-java-valhalla`)
- **Upstream project**: [tree-sitter/tree-sitter-java](https://github.com/tree-sitter/tree-sitter-java) (`v0.23.5`, `MIT`)
- **Tap build defaults**: Regenerates `src/parser.c` from source at Tree-sitter ABI `14` (`tree-sitter generate --abi 14 --js-runtime native`) with this tap's additive JDK 28 Valhalla patch, compiles `libtree-sitter-java-valhalla` (`-std=c11 -O2 -fPIC -shared`), and stages the complete Rust/C crate under `$(brew --prefix tree-sitter-java-valhalla)/share/tree-sitter-java-valhalla` so `ast-grep-valhalla` and `ripwire` compile it in directly.
- **Tap config defaults**: `value` remains a contextual keyword so identifiers, methods, fields, and annotation elements named `value` produce byte-identical syntax trees to upstream `0.23.5`. External `ast-grep` installations can load the shared library opt-in via `customLanguages` in `sgconfig.yml`.

| Syntax | Example | Specification |
| :--- | :--- | :--- |
| Value classes and value records | `value record Point(int x, int y) {}` | JEP 401 (preview) |
| Statements before `super(...)` and `this(...)` | `this.x = x; super();` | JEP 513 |
| Module imports | `import module java.base;` | JEP 511 |
| Qualified record patterns | `o instanceof Shape.Circle(int r)` | JEP 440 |
| Annotations before a varargs ellipsis | `Object @Nullable ... rest` | JLS 8.4.1 |

---

## ast-grep-valhalla

- **Tap formula**: [`Formula/ast-grep-valhalla.rb`](Formula/ast-grep-valhalla.rb) (`brew install artagon/aitools/ast-grep-valhalla`)
- **Upstream project**: [ast-grep/ast-grep](https://github.com/ast-grep/ast-grep) (`0.51.2`, `MIT`) — structural code search, linting, rewriting, and MCP server (`ast-grep` and `sg`).
- **Tap build defaults**: Built from Rust source (`cargo install --locked`, `crates/cli`) with `[patch.crates-io]` replacing `tree-sitter-java` with `artagon/aitools/tree-sitter-java-valhalla`, plus `bash`, `zsh`, `fish`, and `pwsh` completions. Declares `conflicts_with "ast-grep"`.
- **Tap config defaults**: Built-in `-l java` patterns, `sgconfig.yml` lint gates, and `ast-grep lsp` / MCP modes parse JDK 28 Valhalla Java out of the box without `--custom-languages`.

```sh
brew unlink ast-grep   # only when core ast-grep is installed
brew install artagon/aitools/ast-grep-valhalla
```

---

## ripwire

- **Tap formula**: [`Formula/ripwire.rb`](Formula/ripwire.rb) (`brew install artagon/aitools/ripwire`)
- **Upstream project**: [redhat-et/ripwire](https://github.com/redhat-et/ripwire) (`v0.6.10`, `Apache-2.0`) — codebase symbol maps, call graphs, blast-radius analysis, and MCP server (`ripwire --mcp`) for AI coding agents.
- **Tap build defaults**: Built from C++23 source via CMake on macOS 14+ (or Linux with a C++23 toolchain), replacing vendored `tree-sitter-java` `parser.c` with `artagon/aitools/tree-sitter-java-valhalla` and applying an additive `queries/java/tags.scm` patch so records, JEP 401 value records, compact constructors, and `@interface` declarations are indexed as definitions. Installs `ripwire`, `ripwire-agent-install`, and bundled skills/hooks under `$(brew --prefix ripwire)/share/ripwire/`.
- **Tap config defaults**: Installing or upgrading the formula never modifies agent configs or shell profiles. Skill linking and hook registration are strictly opt-in via `ripwire-agent-install` (supporting stock macOS `/bin/bash` 3.2).

```sh
ripwire . --for="find the code that handles authentication"
```

### Optional agent integration (`ripwire-agent-install`)

| Agent CLI | Binary / Environment | Skills Target Path | Hook Support |
| :--- | :--- | :--- | :--- |
| **Claude Code** | `claude` / `~/.claude` | `~/.claude/skills` | `~/.claude/settings.json` (`--hook`) |
| **OpenAI Codex** | `codex` / `~/.codex` | `${AGENTS_HOME:-$HOME/.agents}/skills` | `${CODEX_HOME:-$HOME/.codex}/hooks.json` (`--hook`) |
| **Google Antigravity** | `agy` / `~/.gemini` / existing `AGY_SKILLS_DIR` | `${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}` | MCP server (`ripwire --mcp`) |
| **Moonshot Kimi** | `kimi` / `~/.kimi-code` | `${KIMI_CODE_HOME:-$HOME/.kimi-code}/skills` | MCP server (`ripwire --mcp`) |
| **Grok CLI** | `grok` / `~/.grok` | `${GROK_HOME:-$HOME/.grok}/skills` | MCP server (`ripwire --mcp`) |
| **GitHub Copilot** | `copilot` / `~/.copilot` | `${COPILOT_HOME:-$HOME/.copilot}/skills` | MCP server (`ripwire --mcp`) |
| **Cross-Agent Shared** | APM / multi-agent | `~/.agents/skills` | Standard discovery root |

```sh
# Inspect detected agent CLIs without modifying any files:
ripwire-agent-install --list

# Auto-detect installed CLIs and symlink Ripwire skills (no hooks registered):
ripwire-agent-install

# Explicitly register Claude Code or Codex skills + opt-in advisory hooks:
ripwire-agent-install --claude --hook
ripwire-agent-install --codex --hook
```

---

## tgrep

- **Tap formula**: [`Formula/tgrep.rb`](Formula/tgrep.rb) (`brew install artagon/aitools/tgrep`)
- **Upstream project**: [microsoft/tgrep](https://github.com/microsoft/tgrep) (`v1.2.7`, `MIT`) — trigram-indexed grep with a client/server watcher architecture for sub-second regex sweeps in large repositories.
- **Tap build defaults**: Installs SHA-256-pinned upstream prebuilt release binaries (`aarch64`/`x86_64` macOS and static `musl` Linux) plus `README.md`. Use `artagon/aitools/tgrep` to disambiguate from Homebrew core's `tgrep`.
- **Tap config defaults**: Stores repository indexes locally in `./.tgrep`; no background watcher runs until `tgrep serve .` is started explicitly.

```sh
tgrep index .
tgrep serve . &
tgrep "pattern" .
tgrep status .
```

---

## ck

- **Tap formula**: [`Formula/ck.rb`](Formula/ck.rb) (`brew install artagon/aitools/ck`)
- **Upstream project**: [BeaconBay/ck](https://github.com/BeaconBay/ck) (`0.8.1`, `MIT OR Apache-2.0`) — local regex, BM25 lexical, and semantic hybrid code search CLI with a built-in MCP server (`ck --serve`).
- **Tap build defaults**: Installs SHA-256-pinned upstream release binaries (`aarch64`/`x86_64` macOS and Linux `gnu`, verifying `glibc >= 2.39` on Linux) plus `LICENSE-MIT` and `LICENSE-APACHE`.
- **Tap config defaults**: Keeps repository indexes in `./.ck/`. `--regex` and `--lex` run completely offline; first `--sem` or `--hybrid` run caches an ONNX embedding model in `${XDG_CACHE_HOME:-~/.cache}/ck/models` (Intel macOS upstream binary lacks ONNX Runtime; use `--lex` or `--regex` there).

```sh
ck --regex 'retry_failed_start' .
ck --lex 'failed server start' .
ck --hybrid 'where does the server retry a failed start' .
```

---

## fff-mcp

- **Tap formula**: [`Formula/fff-mcp.rb`](Formula/fff-mcp.rb) (`brew install artagon/aitools/fff-mcp`)
- **Upstream project**: [dmtrKovalenko/fff](https://github.com/dmtrKovalenko/fff) (`v0.11.0`, `MIT`) — fast frecency-ranked fuzzy file search and `grep`/`multi_grep` stdio MCP server.
- **Tap build defaults**: Installs SHA-256-pinned upstream release binary (`depends_on macos: :ventura` on macOS) and stages the matching tag `LICENSE` into `prefix`.
- **Tap config defaults**: Runs as an on-demand stdio MCP server (`$(brew --prefix)/opt/fff-mcp/bin/fff-mcp`); pass `--no-update-check` to disable upstream startup update checks and `--frecency-db <file>` to persist frecency rankings.

---

## hashline

- **Tap formula**: [`Formula/hashline.rb`](Formula/hashline.rb) (`brew install artagon/aitools/hashline`)
- **Upstream project**: [quangdang46/hashline](https://github.com/quangdang46/hashline) (`v0.9.24`, `MIT OR Apache-2.0`) — hash-anchored line reading and deterministic patch application via CLI and stdio MCP server (`hashline mcp`).
- **Tap build defaults**: Compiled from Rust source (`cargo install --locked`, `crates/core` into `libexec`) with an env wrapper at `bin/hashline` and a bundled agent skill at `$(brew --prefix hashline)/share/hashline/skills/hashline/SKILL.md`.
- **Tap config defaults**: Wrapper exports `HASHLINE_NO_UPDATE_CHECK=1` to suppress upstream startup update checks; upgrades are managed exclusively through `brew upgrade artagon/aitools/hashline` (never `hashline update`). Modifies no agent config files.

### MCP registration (`<path>` = `$(brew --prefix)/opt/hashline/bin/hashline`)

| Client | Config file | Config key | Registration command or entry |
| :--- | :--- | :--- | :--- |
| **Claude Code** | `~/.claude.json` | `mcpServers` | `claude mcp add hashline -- <path> mcp` |
| **OpenAI Codex** | `~/.codex/config.toml` | `mcp_servers.hashline` | `command = "<path>"`, `args = ["mcp"]` |
| **Google Antigravity CLI** | `~/.gemini/config/mcp_config.json` | `mcpServers` | `{"command": "<path>", "args": ["mcp"]}` |
| **Cursor / Windsurf** | `~/.cursor/mcp.json` / `~/.codeium/windsurf/mcp_config.json` | `mcpServers` | `{"command": "<path>", "args": ["mcp"]}` |
| **VS Code** | `.vscode/mcp.json` | `servers` | `{"command": "<path>", "args": ["mcp"]}` |

---

## basic-memory

- **Tap formula**: [`Formula/basic-memory.rb`](Formula/basic-memory.rb) (`brew install artagon/aitools/basic-memory`)
- **Upstream project**: [basicmachines-co/basic-memory](https://github.com/basicmachines-co/basic-memory) (`v1.0.0`, `AGPL-3.0-or-later`) — local-first Markdown Zettelkasten knowledge graph CLI (`basic-memory`, `bm`) and stdio JSON-RPC MCP server.
- **Tap build defaults**: Installed from source into an isolated `libexec` `uv` tool environment using managed Python `3.13` (`preserve_rpath` enabled so macOS native wheels retain valid `@rpath` linkage), plus bundled `memory-*` skills under `$(brew --prefix basic-memory)/share/basic-memory/skills`.
- **Tap config defaults**:
  - **Local stdio JSON-RPC only**: `bin/basic-memory` and `bin/bm` export `BASIC_MEMORY_FORCE_LOCAL=true` and `BASIC_MEMORY_EXPLICIT_ROUTING=true`, and reject the top-level `cloud` subcommand, the `--cloud` routing flag, and `--transport streamable-http` / `--transport sse` (exit status `2`).
  - **Zero self-updates, promos, or telemetry**: exports `BASIC_MEMORY_AUTO_UPDATE=false`, `BASIC_MEMORY_NO_PROMOS=1`, `BASIC_MEMORY_CLOUD_PROMO_OPT_OUT=true`, `BASIC_MEMORY_LOGFIRE_ENABLED=false`, and `BASIC_MEMORY_LOGFIRE_SEND_TO_LOGFIRE=false`, and blocks `basic-memory update` / `bm update`.
  - **MCP registration**: `$(brew --prefix)/opt/basic-memory/bin/basic-memory mcp`.

---

## hindsight

- **Tap formula**: [`Formula/hindsight.rb`](Formula/hindsight.rb) (`brew install artagon/aitools/hindsight`)
- **Upstream project**: [vectorize-io/hindsight](https://github.com/vectorize-io/hindsight) (`v1.2.1`, `MIT`) — semantic agent memory bank CLI (`hindsight` `1.2.1`), local stdio MCP server (`hindsight-mcp`), and multi-harness integration CLI (`hindsight-coding-agents` `0.8.7`).
- **Tap build defaults**: Compiles the Rust `hindsight-cli` crate from source (`cargo install --locked`) and bundles the TypeScript `hindsight-integrations/coding-agents` package (`npm ci --ignore-scripts && npm run build`) targeting Homebrew's `node` runtime, installing 5 skill directories under `$(brew --prefix hindsight)/share/hindsight/skills`.
- **Tap config defaults**:
  - **Loopback HTTP + stdio JSON-RPC only**: source patches on `hindsight-cli/src/config.rs`, `coding-agents/src/core/config.ts`, and `coding-agents/src/installer.ts` set default `apiUrl = "http://127.0.0.1:8888"` and `serverMode = "self-hosted"`, remove Hindsight Cloud from interactive and non-interactive installer choices, and fail closed on `cloud` or any endpoint outside `127.0.0.1`, `::1`, or `localhost`.
  - **Explicit harness & no self-updates**: `autoUpdate` is compiled to `false`, `hindsight-coding-agents update` is blocked, and `hindsight-mcp` requires an explicit `HINDSIGHT_MCP_HARNESS` (e.g. `HINDSIGHT_MCP_HARNESS=claude-code $(brew --prefix)/opt/hindsight/bin/hindsight-mcp`) so memories are never stamped under a guessed harness.

---

## qmd

- **Tap formula**: [`Formula/qmd.rb`](Formula/qmd.rb) (`brew install artagon/aitools/qmd`)
- **Upstream project**: [tobi/qmd](https://github.com/tobi/qmd) (`v2.8.3`, `MIT`) — Tobi Lütke's Query Markup Documents: on-device hybrid BM25 full-text search, `sqlite-vec` vector similarity, and local GGUF LLM reranking for Markdown collections via CLI and MCP server.
- **Tap build defaults**: Compiles TypeScript `dist/` from source and installs production Node dependencies + native host addons (`better-sqlite3`, `sqlite-vec`, `tree-sitter-*`, `node-llama-cpp`) into `libexec`, removing `bun.lock`/`pnpm-lock.yaml` to bind Homebrew's `node` and pruning non-host `prebuilds/*` binaries. Installs the bundled skill at `$(brew --prefix qmd)/share/qmd/skills/qmd`.
- **Tap config defaults**: Wrapper exports `QMD_SOURCE_MODE=0`. Runs offline for BM25 search (`qmd search`); first `qmd embed` or `qmd query` downloads GGUF models into `~/.cache/qmd`. Supports stdio MCP (`$(brew --prefix)/opt/qmd/bin/qmd mcp`) and loopback HTTP MCP (`qmd mcp --http`, `localhost:8181`).

---

## squeez

- **Tap formula**: [`Formula/squeez.rb`](Formula/squeez.rb) (`brew install artagon/aitools/squeez`)
- **Upstream project**: [claudioemmanuel/squeez](https://github.com/claudioemmanuel/squeez) (`v1.49.3`, `Apache-2.0`) — zero-dependency Rust CLI output compressor and read-only stdio JSON-RPC MCP server (`squeez mcp`).
- **Tap build defaults**: Compiled from Rust source (`cargo install --locked --bin squeez`) with compile-time patches applied to `src/config.rs`, `src/commands/persona.rs`, and `src/commands/setup.rs` (`DEFAULT_CONFIG_INI`), plus `NOTICE` installed in `prefix`.
- **Tap config defaults**: Enforces conservative defaults both before and after running `squeez setup`: `auto_compress_md = false`, `persona = off`, and `wrap_bash = false`. Wrapper blocks `squeez update` (use `brew upgrade artagon/aitools/squeez`). Register the stdio MCP server with `$(brew --prefix)/opt/squeez/bin/squeez mcp`.

---

## agent-mail

- **Tap formula**: [`Formula/agent-mail.rb`](Formula/agent-mail.rb) (`brew install artagon/aitools/agent-mail`)
- **Upstream project**: [Dicklesworthstone/mcp_agent_mail_rust](https://github.com/Dicklesworthstone/mcp_agent_mail_rust) (`v0.3.40`, `license :cannot_represent` — MIT License with OpenAI/Anthropic Rider; full `LICENSE` installed in `prefix`).
- **Tap build defaults**: Installs SHA-256-pinned upstream release binaries (`mcp-agent-mail` and `am`), `README.md`, and `LICENSE`.
- **Tap config defaults**: Provides stdio MCP (`$(brew --prefix)/opt/agent-mail/bin/mcp-agent-mail`) and local HTTP MCP (`am serve-http`) for multi-agent mail, threads, and advisory file reservations. Do not run `am self-update`; upgrade via Homebrew.

---

## br

- **Tap formula**: [`Formula/br.rb`](Formula/br.rb) (`brew install artagon/aitools/br`)
- **Upstream project**: [Dicklesworthstone/beads_rust](https://github.com/Dicklesworthstone/beads_rust) (`v0.7.6`, `license :cannot_represent` — MIT License with OpenAI/Anthropic Rider; full `LICENSE` installed in `prefix`).
- **Tap build defaults**: Installs SHA-256-pinned upstream `br` binary, `README.md`, `LICENSE`, and generated `bash`/`zsh`/`fish` shell completions.
- **Tap config defaults**: Operates purely on local `.beads/` project state; do not run `br upgrade` (use `brew upgrade artagon/aitools/br`).

---

## bd

- **Tap formula**: [`Formula/bd.rb`](Formula/bd.rb) (`brew install artagon/aitools/bd`)
- **Upstream project**: [gastownhall/beads](https://github.com/gastownhall/beads) (`v1.3.4`, `MIT`) — distributed Git-backed graph issue tracker (`bd`) with embedded pure-Go Dolt storage.
- **Tap build defaults**: Installs SHA-256-pinned upstream `bd` binary (linking only system libraries), `README.md`, `LICENSE`, and shell completions generated with `BD_DISABLE_METRICS=1`. Declares `conflicts_with "beads"`.
- **Tap config defaults**: Embedded Dolt requires no external server. Upstream `bd` enables anonymous telemetry by default at runtime — set `BD_DISABLE_METRICS=1` or run `bd metrics off` to disable it, and pass `--skip-agents` to `bd init` if you do not want project `AGENTS.md` files written.

```sh
brew unlink beads   # only when beads is installed
brew install artagon/aitools/bd
```

---

## bv

- **Tap formula**: [`Formula/bv.rb`](Formula/bv.rb) (`brew install artagon/aitools/bv`)
- **Upstream project**: [Dicklesworthstone/beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) (`v0.26.0`, `license :cannot_represent` — MIT License with OpenAI/Anthropic Rider; full `LICENSE` installed in `prefix`).
- **Tap build defaults**: Installs SHA-256-pinned upstream `bv` binary, `README.md`, `LICENSE`, and Cobra shell completions. Declares `conflicts_with "beads_viewer"`.
- **Tap config defaults**: Read-only terminal UI and `--robot-*` JSON graph triage engine over `.beads/issues.jsonl`; do not run `bv --update`.

```sh
brew unlink beads_viewer   # only when beads_viewer is installed
brew install artagon/aitools/bv
```

---

## adrkit

- **Tap formula**: [`Formula/adrkit.rb`](Formula/adrkit.rb) (`brew install artagon/aitools/adrkit`)
- **Upstream project**: [mbeacom/adrkit](https://github.com/mbeacom/adrkit) (`v0.20.0`, `Apache-2.0`) — Architecture Decision Record CLI (`adr`, `adrkit`) and stdio MCP server (`adrkit-mcp`).
- **Tap build defaults**: Bundles ESM artifacts from TypeScript source with `bun build --target=node` (`--frozen-lockfile --production --ignore-scripts`), wraps `adr`, `adrkit`, and `adrkit-mcp` against Homebrew's `node` binary, generates shell completions, and installs agent skills under `$(brew --prefix adrkit)/share/adrkit/skills`. Declares `conflicts_with "adr-tools"`.
- **Tap config defaults**: Reads and lints `docs/adr` inside a Git worktree by default (`--cwd` and `--dir` override); modifies no agent configuration files.

```sh
brew unlink adr-tools   # only when core adr-tools is installed
brew install artagon/aitools/adrkit
```

---

## nats

- **Tap formula**: [`Formula/nats.rb`](Formula/nats.rb) (`brew install artagon/aitools/nats`)
- **Upstream project**: [nats-io/natscli](https://github.com/nats-io/natscli) (`v0.5.1`, `Apache-2.0`) — CLI for NATS pub/sub, JetStream streams, and KV stores used in multi-agent coordination buses.
- **Tap build defaults**: Compiled from Go source (`*std_go_args(ldflags: "-s -w -X main.version=...")`) with generated `bash` and `zsh` completions. Use `artagon/aitools/nats` to select this tap over Homebrew core's `nats`.
- **Tap config defaults**: Saves connection contexts under `${XDG_CONFIG_HOME:-~/.config}/nats/context`; starts no background server.

---

## herdr

- **Tap formula**: [`Formula/herdr.rb`](Formula/herdr.rb) (`brew install artagon/aitools/herdr`)
- **Upstream project**: [herdrdev/herdr](https://github.com/herdrdev/herdr) (`v0.9.5`, `Apache-2.0`) — multiplexed terminal workspace and session manager for AI coding agents.
- **Tap build defaults**: Installs SHA-256-pinned upstream release binary, matching tag `LICENSE` resource, and generated shell completions. Use `artagon/aitools/herdr` to select this tap.
- **Tap config defaults**: Uses XDG config/state paths (`HERDR_CONFIG_PATH`, `HERDR_SOCKET_PATH`); upgrade via `brew upgrade artagon/aitools/herdr` rather than `herdr update`.

---

## agentsync

- **Tap formula**: [`Formula/agentsync.rb`](Formula/agentsync.rb) (`brew install artagon/aitools/agentsync`)
- **Upstream project**: [dallay/agentsync](https://github.com/dallay/agentsync) (`v1.53.1`, `MIT`) — declarative symlink synchronizer for AI agent rules, skills, and MCP server configs.
- **Tap build defaults**: Installs SHA-256-pinned upstream release binary into `libexec` with an environment wrapper at `bin/agentsync`, plus `README.md` and `LICENSE`.
- **Tap config defaults**: Wrapper exports `AGENTSYNC_NO_UPDATE_CHECK=1`; writes `.agents/agentsync.toml` or target symlinks only when explicitly run by the user.

---

## skillfile

- **Tap formula**: [`Formula/skillfile.rb`](Formula/skillfile.rb) (`brew install artagon/aitools/skillfile`)
- **Upstream project**: [eljulians/skillfile](https://github.com/eljulians/skillfile) (`v1.9.2`, `Apache-2.0`) — declarative `Skillfile` package manager and validator for AI coding agent skills.
- **Tap build defaults**: Compiled from Rust source (`cargo install --locked`, `crates/cli` into `libexec`) with generated shell completions and an env wrapper at `bin/skillfile`.
- **Tap config defaults**: Wrapper exports `SKILLFILE_NO_UPDATE_NOTIFIER=1`; upgrades are managed through `brew upgrade artagon/aitools/skillfile`.

---

## skillprism

- **Tap formula**: [`Formula/skillprism.rb`](Formula/skillprism.rb) (`brew install artagon/aitools/skillprism`)
- **Upstream project**: [Tuvren/skillprism](https://github.com/Tuvren/skillprism) (`v0.5.0`, `Apache-2.0`) — template compiler rendering multi-harness AI agent skills from `SKILL.md.j2` and `skill.yaml`.
- **Tap build defaults**: Compiled from Rust source (`cargo install --locked`) with generated shell completions and `man1/skillprism.1` man page.
- **Tap config defaults**: Compiles local `skillprism.yaml` projects into `./dist/<harness>/` with no network calls or live agent config modifications.

---

## Automatic version updates

[`autobump.yml`](.github/workflows/autobump.yml) runs daily and on demand. Each formula's `livecheck` block finds the latest upstream release, and [`scripts/autobump.sh`](scripts/autobump.sh) opens one pull request per new version. The script moves every literal-versioned URL to the new release and recomputes its SHA-256, so multi-platform binary formulae bump the same way as single-archive source formulae. A `tree-sitter-java-valhalla` bump also increments the `revision` of `ast-grep-valhalla` and `ripwire`.

## Bottles and publishing

Every pull request runs [`tests.yml`](.github/workflows/tests.yml): `brew test-bot` builds, tests, and bottles changed formulae on a `macos-26` Apple Silicon runner, runs the provenance and installer suites, and generates SPDX 2.3 and CycloneDX 1.6 SBOMs plus `build-manifest.json` (`scripts/ci/build-provenance-manifest.sh`). After reviewing the diff, publish from `main`:

```sh
gh workflow run publish.yml -f pull_request=<number> \
  -f head_sha="$(gh pr view <number> --json headRefOid --jq .headRefOid)"
```

[`publish.yml`](.github/workflows/publish.yml) snapshots trusted `scripts/` from `main` before applying PR commits and separates staging, OIDC signing, and publishing:

1. `stage-bottles` (`contents: read`) validates PR ancestry and workflow/CI-script guards (`scripts/ci/publish-bottles.sh`), verifies `bottles_macos-26` and `provenance_macos-26` ZIP digests, runs `brew pr-pull --no-upload`, merges `bottle do` blocks, and refreshes the `README.md` bottle provenance table (`scripts/update-readme-bottles.sh`).
2. [`sign-bottles.yml`](.github/workflows/sign-bottles.yml) (`@refs/heads/main`) verifies the builder run's `head_sha` via the GitHub API (`scripts/ci/sign-and-attest.sh`), mints SLSA v1 and `bottle-lineage/v1` attestations, signs Sigstore `cosign` v3 bundles, self-verifies online and air-gapped offline, and uploads assets to draft GitHub Releases (`<formula>-<pkg_version>`).
3. `push-main` enforces block-aware `bottle do ... end` and fenced `README.md` diff policy (`scripts/ci/verify-patch-policy.sh`), pushes `main`, publishes the draft releases, and verifies every bottle with `brew verify`.

Do not merge formula pull requests directly; formulae would ship without bottles or attestations. To backfill or refresh provenance sidecars on already-published releases from `main`:

```sh
gh workflow run attest.yml
gh workflow run attest.yml -f formulae="ripwire ast-grep-valhalla"
```

Bump pull requests follow the same path; `scripts/autobump.sh` dispatches `tests.yml` on each one.
A bump fails on purpose when:

- the grammar patch or Ripwire's query patch no longer applies;
- ast-grep pins a tree-sitter-java version that the patched crate cannot replace; or
- Ripwire changes its bundled installer or skills, which `tests/integration-agent-install.sh` pins.

One-time repository setting: in Settings → Actions → General, allow GitHub Actions to create and
approve pull requests. To check or apply bumps locally:

```sh
scripts/autobump.sh check
scripts/autobump.sh write tgrep
```

## Build provenance and verification

Published bottles ship with cryptographic build provenance attested by [`.github/workflows/sign-bottles.yml`](.github/workflows/sign-bottles.yml) on `refs/heads/main`. Each GitHub Release (`<formula>-<pkg_version>`) carries the bottle tarball and 8 sidecars:

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
| [`ast-grep-valhalla`](Formula/ast-grep-valhalla.rb) | `0.51.2` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ast-grep-valhalla-0.51.2) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz) · [`f4096656461f…`](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:f4096656461fc9a4aa1b4f52a9a6c4750e480c2620b94b99e7cd1070815e7c40) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.2/ast-grep-valhalla-0.51.2.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`basic-memory`](Formula/basic-memory.rb) | `1.0.0` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/basic-memory-1.0.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz) · [`e52a2558fdf3…`](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:e52a2558fdf3b002f2ec78f8fa8f881ee5cf9db9cadf00571634cdfae1eafead) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.1.tar.gz.cdx.json) |
| [`bd`](Formula/bd.rb) | `1.3.4` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/bd-1.3.4) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz) · [`c6f3d9bdcb50…`](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:c6f3d9bdcb5041c9ece17e6b11dacbde40b46d5ef86b1199167f47056d9b0235) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`br`](Formula/br.rb) | `0.7.6` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/br-0.7.6) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz) · [`e79478b19802…`](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:e79478b198025358c79c6dc57d6f13c384bcc3ded7f1076aafb19978e3ea38c6) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`bv`](Formula/bv.rb) | `0.26.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/bv-0.26.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz) · [`949c3e637953…`](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:949c3e637953729383216d0af65738b4918120332f1190caf0c321c4e81d6eb3) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`ck`](Formula/ck.rb) | `0.8.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ck-0.8.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz) · [`5f2e284ae568…`](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:5f2e284ae5689eab88e4ba9028e3cc43651d81b7a301b5b91cd5e71fc3c47630) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`fff-mcp`](Formula/fff-mcp.rb) | `0.11.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/fff-mcp-0.11.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz) · [`b4e95d364d63…`](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:b4e95d364d63360fdb85a30b2575c039f5d65754ca12ec0fe555d393d2901719) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`hashline`](Formula/hashline.rb) | `0.9.24` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/hashline-0.9.24) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz) · [`458689231f7f…`](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:458689231f7f42afa5575edfce9d06d49911cd8064019befdbc928a1c28c9914) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24/hashline-0.9.24.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`herdr`](Formula/herdr.rb) | `0.9.5` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/herdr-0.9.5) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz) · [`4dfdf6be14ea…`](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:4dfdf6be14ea11c985bda408b1d946552e6a048e661e26c844df4fffd16a28c3) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`hindsight`](Formula/hindsight.rb) | `1.2.1` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/hindsight-1.2.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz) · [`08cac7e08ebb…`](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:08cac7e08ebbbda7c8d8498f6e4fc64598de0ba2997b0f2b512a674a121f3221) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/hindsight-1.2.1/hindsight-1.2.1.arm64_tahoe.bottle.1.tar.gz.cdx.json) |
| [`nats`](Formula/nats.rb) | `0.5.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/nats-0.5.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz) · [`7b52481a53a5…`](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:7b52481a53a5987e4b68941e3c3d27afe9f7f1d51fc4294e67c473a72b740fa1) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`qmd`](Formula/qmd.rb) | `2.8.3` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/qmd-2.8.3) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz) · [`b217890db1c7…`](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:b217890db1c72ca5e9222abbd07ea8a7d159278827882d9fea52fb521cb85c72) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.1.tar.gz.cdx.json) |
| [`ripwire`](Formula/ripwire.rb) | `0.6.10` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ripwire-0.6.10) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz) · [`159e3433d7b7…`](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:159e3433d7b71bf36efb30bf9bad05f7a3eb8ac62cc6ebc5275c95e13d348498) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`skillfile`](Formula/skillfile.rb) | `1.9.2` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/skillfile-1.9.2) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz) · [`e7241c41a16a…`](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:e7241c41a16a3dab3fcbf0e8e98a805906c7e2fa61fc2dfac7aac6c4f07673db) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.2/skillfile-1.9.2.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`skillprism`](Formula/skillprism.rb) | `0.5.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/skillprism-0.5.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz) · [`bc2d0a115955…`](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:bc2d0a11595523e14ffd7ae94202485d47ba5199355f9febfb3f32a68c24fd56) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`squeez`](Formula/squeez.rb) | `1.49.3` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/squeez-1.49.3) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz) · [`01a46ebc252c…`](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:01a46ebc252ce17c51754a7905b86cac6773245b34200d4b423bfbc81c0d3be4) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/squeez-1.49.3/squeez-1.49.3.arm64_tahoe.bottle.1.tar.gz.cdx.json) |
| [`tgrep`](Formula/tgrep.rb) | `1.2.7` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/tgrep-1.2.7) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz) · [`718b1691a9b7…`](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:718b1691a9b773922513479892c527484a738f3b0601385c080da6e6dec62d10) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`tree-sitter-java-valhalla`](Formula/tree-sitter-java-valhalla.rb) | `0.23.5` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/tree-sitter-java-valhalla-0.23.5) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz) · [`3090dc558d97…`](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:3090dc558d979c821fc9da23d2fc5a00e4143c5f33fec80c53ba63c9c1755109) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.tar.gz.cdx.json) |
<!-- END BOTTLE_PROVENANCE_TABLE -->

### 1. Native Homebrew verification

Enable Homebrew's built-in attestation verification (requires `gh` authenticated to `github.com` or `HOMEBREW_GITHUB_API_TOKEN`):

```sh
HOMEBREW_VERIFY_ATTESTATIONS=1 brew install artagon/aitools/ripwire
brew verify --bottle-tag=arm64_tahoe artagon/aitools/ripwire
```

### 2. Strict multi-layer & air-gapped verification (`scripts/verify-provenance.sh`)

[`scripts/verify-provenance.sh`](scripts/verify-provenance.sh) enforces the exact signer SAN (`...@refs/heads/main`), `--source-ref refs/heads/main`, `--deny-self-hosted-runners`, atomic `--` + `-` dual-subject binding, signed `bottle-lineage/v1` SBOM digests, and Sigstore `cosign` v3 bundles:

```sh
# Online check for one formula or all bottled formulae:
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
gh attestation verify ripwire-0.6.10.arm64_tahoe.bottle.tar.gz \
  --repo artagon/homebrew-aitools \
  --cert-identity "https://github.com/artagon/homebrew-aitools/.github/workflows/sign-bottles.yml@refs/heads/main" \
  --source-ref "refs/heads/main" \
  --deny-self-hosted-runners

# Sigstore cosign v3 (blob signature + SPDX attestation):
cosign verify-blob \
  --bundle ripwire-0.6.10.arm64_tahoe.bottle.tar.gz.sigstore.json \
  --certificate-identity "https://github.com/artagon/homebrew-aitools/.github/workflows/sign-bottles.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ripwire-0.6.10.arm64_tahoe.bottle.tar.gz
```

**Scope & SBOM coverage notes**:
- Source-built formulae (`tree-sitter-java-valhalla`, `ast-grep-valhalla`, `ripwire`, `hashline`, `basic-memory`, `hindsight`, `qmd`, `squeez`, `adrkit`, `nats`, `skillfile`, `skillprism`) attest compilation in `tests.yml` on GitHub-hosted `macos-26` runners; upstream-binary formulae (`tgrep`, `ck`, `fff-mcp`, `agent-mail`, `br`, `bd`, `bv`, `herdr`, `agentsync`) attest bottle packaging of the SHA-256-pinned upstream release asset.
- Go binaries (`bd`, `bv`, `nats`, `tgrep`), Python wheel metadata (`basic-memory`), Node `package.json` inventories (`hindsight`, `qmd`), and `cargo-auditable` Rust binaries expose full package inventories to `syft`, whereas standard Rust/C/C++ binaries without embedded audit metadata and `adrkit` (`bun` single-file JS bundle) expose bottle archive and manifest files only.

## Validation

See [integration and provenance tests](tests/README.md) for isolated checks under stock macOS `/bin/bash` 3.2 and modern Bash 5+:
- `tests/integration-agent-install.sh` exercises both Ripwire activation entrypoints and opt-in hook registration against the real bundled payload in temporary agent homes.
- `tests/test-verify-provenance.sh` exercises `scripts/verify-provenance.sh`, `scripts/update-readme-bottles.sh`, and `scripts/ci/*` across all bottled formulae, online and air-gapped offline bundles, tamper rejection, and isolated `--homebrew` verification without touching live user state.
