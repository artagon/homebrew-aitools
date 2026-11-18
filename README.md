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

# Architecture decisions, skill evaluation/optimization, and agent config management:
brew install artagon/aitools/adrkit
brew install artagon/aitools/agentsync
brew install artagon/aitools/skillfile
brew install artagon/aitools/skillprism
brew install artagon/aitools/waza
brew install artagon/aitools/skillopt

# Subscription-only AI gateway & terminal coding agents (no API keys):
brew install artagon/aitools/magpie
brew install artagon/aitools/omp
brew install artagon/aitools/pi-agent-rust
```

Use the fully qualified `artagon/aitools/<formula>` names to select this tap. Homebrew core also ships same-named `tgrep`, `nats`, and `herdr` formulae, plus differently named formulae that install overlapping binaries (`ast-grep`, `beads`, `beads_viewer`, `adr-tools`, `cln`, and `pi-coding-agent`; run `brew unlink <formula>` first when one of those is already linked). Installing, upgrading, or uninstalling any formula in this tap **never** modifies live user agent configuration files (`~/.claude`, `~/.codex`, `~/.gemini`, `~/.config`, etc.).

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
| [`waza`](Formula/waza.rb) | [microsoft/waza](https://github.com/microsoft/waza) (`MIT`) | CLI and embedded web dashboard for evaluating and benchmarking AI agent workflows, custom agents, and skills | Source build: Vite/React `web/` SPA (`npm ci --ignore-scripts && npm run build`, `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`) + Go `cmd/waza` into `libexec`; generates shell completions; installs `pkgshare/skills/{waza,waza-interactive}` | Wrapper exports `WAZA_NO_UPDATE_CHECK=1` and blocks `waza update` (exit `2`); zero agent config mutation |
| [`skillopt`](Formula/skillopt.rb) | [microsoft/SkillOpt](https://github.com/microsoft/SkillOpt) (`MIT`) | Reflective text-space skill optimizer (`skillopt-train`, `skillopt-eval`) and offline sleep consolidation CLI & MCP (`skillopt-sleep`, `skillopt-sleep-mcp`) | Source build via `uv` (managed Python `3.13`, `--no-cache`, `preserve_rpath`); patches `mcp_server.py` default `REPO_ROOT` to caller `os.getcwd()`; installs `pkgshare/{plugins,configs}` | `skillopt-sleep` defaults to `--backend mock` (zero API spend) and stages proposals for review before `adopt`; local stdio MCP (`skillopt-sleep-mcp`); zero agent config or cron mutation |
| [`magpie`](Formula/magpie.rb) | [yetone/magpie](https://github.com/yetone/magpie) (`MIT`) | Subscription-first local AI gateway & smart router (`magpie`) for Claude, Codex, Copilot, and Gemini accounts | Source build (`go build` with embedded `packedassets`; macOS `production` WebKit tray + Linux static `nogui`); installs `THIRD_PARTY_NOTICES` and `pkgshare/examples/subscription-only/setup-groups.sh` | **CLI-subscription-only loopback (`127.0.0.1:3425`)**: telemetry, auto-updates, and background PII model downloads disabled; API-key providers and paid subscription extra-usage/credits blocked unless `MAGPIE_ALLOW_API_KEYS=1` / `MAGPIE_ALLOW_CREDITS=1`; `magpie update` blocked (exit `2`) |
| [`omp`](Formula/omp.rb) | [can1357/oh-my-pi](https://github.com/can1357/oh-my-pi) (`MIT`) | Terminal AI coding agent (`omp`) with Rust `pi-natives` N-API core, hashline editing, LSP, DAP, and role routing | SHA-256-pinned upstream release binary into `libexec` + tag `LICENSE` resource; generates shell completions; stages `pkgshare/examples/subscription-only/{models.yml,config.yml}` | **CLI-subscription-only wrapper**: injects `homebrew-policy.yml` (`checkUpdate: false`, `update.auto: false`, `otlpExportEnabled: false`), disables OTel/AutoQA/Spotlight, scrubs ambient `*_API_KEY` env vars, and blocks `omp update`, `--api-key`, and `--include-env` (exit `2`) unless `OMP_ALLOW_API_KEYS=1` |
| [`pi-agent-rust`](Formula/pi-agent-rust.rb) | [Dicklesworthstone/pi_agent_rust](https://github.com/Dicklesworthstone/pi_agent_rust) (`:cannot_represent` — MIT + Rider) | Safe-Rust AI coding agent CLI (`pi`, `rpi`) with hashline editing and sub-100ms startup | SHA-256-pinned upstream release archive into `libexec` + full custom `LICENSE` in `prefix`; generates completions; installs `pkgshare/skills/pi-agent-rust` & `examples/subscription-only` (`conflicts_with "cln"`, `"pi-coding-agent"`) | **CLI-subscription-only wrappers (`pi`, `rpi`)**: exports `PI_SKIP_VERSION_CHECK=1` and `DO_NOT_TRACK=true`, scrubs ambient `*_API_KEY` env vars, and blocks `self-update` and `--api-key` (exit `2`) unless `PI_ALLOW_API_KEYS=1` |

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
- **Upstream project**: [ast-grep/ast-grep](https://github.com/ast-grep/ast-grep) (`0.51.3`, `MIT`) — structural code search, linting, rewriting, and MCP server (`ast-grep` and `sg`).
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

## waza

- **Tap formula**: [`Formula/waza.rb`](Formula/waza.rb) (`brew install artagon/aitools/waza`)
- **Upstream project**: [microsoft/waza](https://github.com/microsoft/waza) (`v0.41.0`, `MIT`) — CLI and embedded React dashboard for evaluating, grading, and benchmarking AI agent workflows, custom agents, and skills.
- **Tap build defaults**: Builds the `web/` Vite/React dashboard from source (`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`, `npm ci --ignore-scripts && npm run build`), embeds it into the Go `cmd/waza` binary (`*std_go_args(output: libexec/"waza", ldflags: "-s -w -X main.version=...")`), generates `bash`/`zsh`/`fish` shell completions, and installs bundled skills under `$(brew --prefix waza)/share/waza/skills/{waza,waza-interactive}`.
- **Tap config defaults**: Wrapper exports `WAZA_NO_UPDATE_CHECK=1` by default and rejects the in-place `waza update` self-updater (exit status `2`; upgrade via `brew upgrade artagon/aitools/waza`). Modifies no agent configuration files.

```sh
waza init --no-skill ./my-evals
waza check
waza run
```

---

## skillopt

- **Tap formula**: [`Formula/skillopt.rb`](Formula/skillopt.rb) (`brew install artagon/aitools/skillopt`)
- **Upstream project**: [microsoft/SkillOpt](https://github.com/microsoft/SkillOpt) (`v0.2.0`, `MIT`) — reflective text-space skill optimizer (`skillopt-train`, `skillopt-eval`), offline session sleep consolidation CLI (`skillopt-sleep`), and stdlib-only local stdio JSON-RPC MCP server (`skillopt-sleep-mcp`).
- **Tap build defaults**: Installed from source into an isolated `libexec` `uv` tool environment using managed Python `3.13` (`preserve_rpath` + `@rpath` dylib normalization on macOS), patches `plugins/copilot/mcp_server.py` so `REPO_ROOT` defaults to `os.getcwd()` when `SKILLOPT_SLEEP_REPO` is unset, and installs agent plugins (`claude-code`, `codex`, `copilot`, `devin`, `openclaw`) and experiment `configs` under `$(brew --prefix skillopt)/share/skillopt/`.
- **Tap config defaults**: `skillopt-sleep` defaults to `--backend mock` (zero API spend) and stages proposals for human review (`nothing live changes until skillopt-sleep adopt`). Register the stdio MCP server with `$(brew --prefix)/opt/skillopt/bin/skillopt-sleep-mcp`. Modifies no agent configuration files or cron schedules on install.

```sh
skillopt-sleep status --project . --json
skillopt-sleep dry-run --project .
```

---

## magpie

- **Tap formula**: [`Formula/magpie.rb`](Formula/magpie.rb) (`brew install artagon/aitools/magpie`)
- **Upstream project**: [yetone/magpie](https://github.com/yetone/magpie) (`v0.1.4403`, `MIT`) — subscription-first local gateway and smart router (`127.0.0.1:3425`) unifying Anthropic Messages, OpenAI Responses, Chat Completions, and Gemini protocols over flat-rate CLI OAuth accounts.
- **Tap build defaults**: Compiled from Go source with embedded `packedassets` (`production` WebKit menu-bar build on macOS; static `CGO_ENABLED=0 -tags "nogui packedassets"` headless/TUI/web build on Linux), `THIRD_PARTY_NOTICES`, and a subscription-only routing bootstrap script at `$(brew --prefix magpie)/share/magpie/examples/subscription-only/setup-groups.sh`.
- **Tap config defaults**:
  - **CLI subscriptions only (zero API keys, zero overage billing)**: API-key provider creation/routing and Claude/Codex paid extra-usage credits are disabled unless `MAGPIE_ALLOW_API_KEYS=1` or `MAGPIE_ALLOW_CREDITS=1` is explicitly set.
  - **Zero telemetry or background downloads**: `noStats`, `noUsageStats`, `noAutoUpdate`, `noAutoDownload`, `noUpdatePill`, and `redactModelOff` are enabled by default, and `magpie update` exits `2` (`brew upgrade artagon/aitools/magpie`).

```sh
magpie accounts add claude
magpie accounts add codex
magpie accounts add copilot
magpie accounts add gemini
magpie serve
```

---

## omp

- **Tap formula**: [`Formula/omp.rb`](Formula/omp.rb) (`brew install artagon/aitools/omp`)
- **Upstream project**: [can1357/oh-my-pi](https://github.com/can1357/oh-my-pi) (`v18.22.2`, `MIT`) — terminal AI coding agent with a Rust `pi-natives` N-API core (`grep`, `ast_grep`, `ast_edit`, PTY, text-buffer), hashline editing, LSP, DAP, and multi-role model routing.
- **Tap build defaults**: Installs SHA-256-pinned upstream release binary into `libexec/omp`, matching tag `LICENSE` into `prefix`, generated `bash`/`zsh`/`fish` completions, `libexec/homebrew-policy.yml`, and ready-to-copy Magpie subscription-only configs under `$(brew --prefix omp)/share/omp/examples/subscription-only/{models.yml,config.yml}`.
- **Tap config defaults**: Wrapper prepends `homebrew-policy.yml` via `PI_CONFIG_FILES` (`startup.checkUpdate: false`, `update.auto: false`, `telemetry.otlpExportEnabled: false`), exports `OTEL_SDK_DISABLED=true`, `DO_NOT_TRACK=true`, `PI_AUTO_QA=0`, and `PI_SPOTLIGHT_EXPERIMENT=0`, scrubs ambient `*_API_KEY` and cloud token environment variables, and blocks `omp update`, `--api-key`, and `auth-broker migrate --include-env` (exit status `2`; set `OMP_ALLOW_API_KEYS=1` to override).

```sh
omp auth-broker login anthropic
omp auth-broker login openai-codex
# Or wire omp through local loopback magpie:
magpie oh-my-pi group/sub-coder
```

---

## pi-agent-rust

- **Tap formula**: [`Formula/pi-agent-rust.rb`](Formula/pi-agent-rust.rb) (`brew install artagon/aitools/pi-agent-rust`)
- **Upstream project**: [Dicklesworthstone/pi_agent_rust](https://github.com/Dicklesworthstone/pi_agent_rust) (`v0.8.0`, `license :cannot_represent` — MIT License with OpenAI/Anthropic Rider; full `LICENSE` installed in `prefix`).
- **Tap build defaults**: Installs SHA-256-pinned upstream `pi` binary into `libexec/pi` with `bin/pi` and `bin/rpi` wrappers, `LICENSE`, `README.md`, generated shell completions, bundled skills under `$(brew --prefix pi-agent-rust)/share/pi-agent-rust/skills/pi-agent-rust`, and Magpie subscription-only JSON templates under `$(brew --prefix pi-agent-rust)/share/pi-agent-rust/examples/subscription-only/`. Declares `conflicts_with "cln"` and `conflicts_with "pi-coding-agent"`.
- **Tap config defaults**: Both `pi` and `rpi` export `PI_SKIP_VERSION_CHECK=1`, `DO_NOT_TRACK=true`, and `PI_SUBAGENT_PI_BINARY`, scrub ambient `*_API_KEY` environment variables, and reject `self-update` and `--api-key` (exit status `2`; set `PI_ALLOW_API_KEYS=1` to override).

```sh
brew unlink cln pi-coding-agent   # only when either is installed
brew install artagon/aitools/pi-agent-rust
```

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
- Ripwire changes its bundled installer or skills, which `tests/helpers/agent_install_helper.bash` pins.

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

| Formula | Platform & Version | Bottle & SHA-256 | Provenance Certificates & Proofs | Signed SBOMs |
| :--- | :--- | :--- | :--- | :--- |
| [`agent-mail`](Formula/agent-mail.rb) | `arm64_tahoe` · `0.3.40` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/agent-mail-0.3.40) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz) · [`2dcff69a3a2a…`](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:2dcff69a3a2ac74e215f4f74bec75ad93e4124ce0e99f8de213abbb85721179f) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.40/agent-mail-0.3.40.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`agentsync`](Formula/agentsync.rb) | `arm64_tahoe` · `1.53.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/agentsync-1.53.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz) · [`a7ac20920d6d…`](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:a7ac20920d6d1edbdb7d93d91db75f9fe113c285cf393309eb5fbd78d017de37) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1/agentsync-1.53.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`ast-grep-valhalla`](Formula/ast-grep-valhalla.rb) | `arm64_tahoe` · `0.51.3` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ast-grep-valhalla-0.51.3) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz) · [`3118d656124f…`](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:3118d656124f43a41f459f7c20f42037cb2d877d1d3c00a0c1a3ea4959b79448) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_tahoe.bottle.2.tar.gz.cdx.json) |
| [`ast-grep-valhalla`](Formula/ast-grep-valhalla.rb) | `arm64_linux` · `0.51.3` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ast-grep-valhalla-0.51.3) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz) · [`ea20da9cf7eb…`](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:ea20da9cf7eb073d6623c48a79686fe5e9ca4346aaa975ea163bd2b2eb07e664) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.arm64_linux.bottle.2.tar.gz.cdx.json) |
| [`ast-grep-valhalla`](Formula/ast-grep-valhalla.rb) | `x86_64_linux` · `0.51.3` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ast-grep-valhalla-0.51.3) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz) · [`1b0b89d301be…`](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:1b0b89d301be4b8b58521aead1eb4e07a11791efb65cc547daaec247a8529ba7) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ast-grep-valhalla-0.51.3/ast-grep-valhalla-0.51.3.x86_64_linux.bottle.2.tar.gz.cdx.json) |
| [`basic-memory`](Formula/basic-memory.rb) | `arm64_tahoe` · `1.0.0` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/basic-memory-1.0.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz) · [`47807f25102c…`](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:47807f25102ce5891408bd94ccbfa893ff2175caffef7c900e4ec951f86678f7) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_tahoe.bottle.2.tar.gz.cdx.json) |
| [`basic-memory`](Formula/basic-memory.rb) | `arm64_linux` · `1.0.0` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/basic-memory-1.0.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz) · [`f0fc4b61e71d…`](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:f0fc4b61e71d22219e1efd77967530341fbd695c6d40f1959f640637b4b787e7) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.arm64_linux.bottle.2.tar.gz.cdx.json) |
| [`basic-memory`](Formula/basic-memory.rb) | `x86_64_linux` · `1.0.0` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/basic-memory-1.0.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz) · [`54f864b976a3…`](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:54f864b976a3d3f03ed0d99d53d3b5f19e13c51d43a3633488991d5202dde778) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/basic-memory-1.0.0/basic-memory-1.0.0.x86_64_linux.bottle.2.tar.gz.cdx.json) |
| [`bd`](Formula/bd.rb) | `arm64_tahoe` · `1.3.4` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/bd-1.3.4) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz) · [`c6f3d9bdcb50…`](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:c6f3d9bdcb5041c9ece17e6b11dacbde40b46d5ef86b1199167f47056d9b0235) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4/bd-1.3.4.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`br`](Formula/br.rb) | `arm64_tahoe` · `0.7.6` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/br-0.7.6) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz) · [`e79478b19802…`](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:e79478b198025358c79c6dc57d6f13c384bcc3ded7f1076aafb19978e3ea38c6) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/br-0.7.6/br-0.7.6.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`bv`](Formula/bv.rb) | `arm64_tahoe` · `0.26.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/bv-0.26.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz) · [`949c3e637953…`](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:949c3e637953729383216d0af65738b4918120332f1190caf0c321c4e81d6eb3) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/bv-0.26.0/bv-0.26.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`ck`](Formula/ck.rb) | `arm64_tahoe` · `0.8.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ck-0.8.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz) · [`5f2e284ae568…`](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:5f2e284ae5689eab88e4ba9028e3cc43651d81b7a301b5b91cd5e71fc3c47630) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ck-0.8.1/ck-0.8.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`fff-mcp`](Formula/fff-mcp.rb) | `arm64_tahoe` · `0.11.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/fff-mcp-0.11.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz) · [`b4e95d364d63…`](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:b4e95d364d63360fdb85a30b2575c039f5d65754ca12ec0fe555d393d2901719) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/fff-mcp-0.11.0/fff-mcp-0.11.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`herdr`](Formula/herdr.rb) | `arm64_tahoe` · `0.9.5` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/herdr-0.9.5) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz) · [`4dfdf6be14ea…`](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:4dfdf6be14ea11c985bda408b1d946552e6a048e661e26c844df4fffd16a28c3) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5/herdr-0.9.5.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`magpie`](Formula/magpie.rb) | `arm64_tahoe` · `0.1.4403` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/magpie-0.1.4403) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz) · [`033162e0f1c6…`](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:033162e0f1c63f3a88c0cc49ace42d635937082659625fb2ab45c8d012bc67e8) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`magpie`](Formula/magpie.rb) | `arm64_linux` · `0.1.4403` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/magpie-0.1.4403) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz) · [`646a1d7a1a3d…`](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:646a1d7a1a3df01d96cb11b3847544bdd2fbbe6ab79c15df4cb124b874048a51) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.arm64_linux.bottle.tar.gz.cdx.json) |
| [`magpie`](Formula/magpie.rb) | `x86_64_linux` · `0.1.4403` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/magpie-0.1.4403) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz) · [`a543272ed758…`](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:a543272ed7586c5580410b23237686383f39867a9c1caaf195ad0336e99c9193) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4403/magpie-0.1.4403.x86_64_linux.bottle.tar.gz.cdx.json) |
| [`nats`](Formula/nats.rb) | `arm64_tahoe` · `0.5.1` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/nats-0.5.1) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz) · [`7b52481a53a5…`](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:7b52481a53a5987e4b68941e3c3d27afe9f7f1d51fc4294e67c473a72b740fa1) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/nats-0.5.1/nats-0.5.1.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`omp`](Formula/omp.rb) | `arm64_tahoe` · `18.22.2` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/omp-18.22.2) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz) · [`63aef2cf2c00…`](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:63aef2cf2c008db2c40f94de1e5deea3605f6d8e001c9d182322ece91f9748e5) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`omp`](Formula/omp.rb) | `arm64_linux` · `18.22.2` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/omp-18.22.2) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz) · [`3d76befddcdd…`](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:3d76befddcddd95f8cbb34632d0d9c7acc2d07ffeecc92d1e5516853f939fe5a) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.arm64_linux.bottle.tar.gz.cdx.json) |
| [`omp`](Formula/omp.rb) | `x86_64_linux` · `18.22.2` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/omp-18.22.2) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz) · [`1a840942ac6c…`](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:1a840942ac6cf4864eae594fc5175b77e4bb74768bcfbb744138eb93eacdd9c7) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/omp-18.22.2/omp-18.22.2.x86_64_linux.bottle.tar.gz.cdx.json) |
| [`pi-agent-rust`](Formula/pi-agent-rust.rb) | `arm64_tahoe` · `0.8.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/pi-agent-rust-0.8.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz) · [`dd8d8e2e3694…`](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:dd8d8e2e36948a2f3b8d309553942e5dadefe40bb73f929ca19bff8f458aaa8c) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`pi-agent-rust`](Formula/pi-agent-rust.rb) | `arm64_linux` · `0.8.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/pi-agent-rust-0.8.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz) · [`f44a133dc5cd…`](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:f44a133dc5cd6667a1e8632dcac3f60ca8d038ff81a7686e973214078a5b0ea6) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.arm64_linux.bottle.tar.gz.cdx.json) |
| [`pi-agent-rust`](Formula/pi-agent-rust.rb) | `x86_64_linux` · `0.8.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/pi-agent-rust-0.8.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz) · [`226e8e5c4c7b…`](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:226e8e5c4c7b373d08f33a6a44dfeea2bbe930449c900768af2ae242b63ad5b3) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/pi-agent-rust-0.8.0/pi-agent-rust-0.8.0.x86_64_linux.bottle.tar.gz.cdx.json) |
| [`qmd`](Formula/qmd.rb) | `arm64_tahoe` · `2.8.3` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/qmd-2.8.3) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz) · [`97c6cc1b6122…`](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:97c6cc1b6122539e35451cb79e63ae5d60f46a647218ff2a8c05f994e44ba468) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_tahoe.bottle.2.tar.gz.cdx.json) |
| [`qmd`](Formula/qmd.rb) | `arm64_linux` · `2.8.3` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/qmd-2.8.3) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz) · [`dcb80a8f6d65…`](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:dcb80a8f6d657f21f9b6bf5e413c404345f6b1e294c0c2b4d88fefcbe2933af0) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.arm64_linux.bottle.2.tar.gz.cdx.json) |
| [`qmd`](Formula/qmd.rb) | `x86_64_linux` · `2.8.3` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/qmd-2.8.3) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz) · [`78b1cdb0a4e5…`](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:78b1cdb0a4e5e0fc6fb11e46df5981881ea71de0c12b4117582285bafb41f76d) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3/qmd-2.8.3.x86_64_linux.bottle.2.tar.gz.cdx.json) |
| [`ripwire`](Formula/ripwire.rb) | `arm64_tahoe` · `0.6.10` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ripwire-0.6.10) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz) · [`4349b25baf93…`](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:4349b25baf93c575162b394236de7415a0123ec01b2089d1c7a64da46c49ab81) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_tahoe.bottle.1.tar.gz.cdx.json) |
| [`ripwire`](Formula/ripwire.rb) | `arm64_linux` · `0.6.10` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ripwire-0.6.10) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz) · [`c5c564e12c57…`](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:c5c564e12c57279e398931156dd6cd24ed3e470e602b43f547fcb80eacabdf7e) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.arm64_linux.bottle.1.tar.gz.cdx.json) |
| [`ripwire`](Formula/ripwire.rb) | `x86_64_linux` · `0.6.10` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/ripwire-0.6.10) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz) · [`9906da2e0174…`](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:9906da2e0174dcfd966fff73fcafefc1add524058bc0f5185468f9aadc798a2b) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/ripwire-0.6.10/ripwire-0.6.10.x86_64_linux.bottle.1.tar.gz.cdx.json) |
| [`skillopt`](Formula/skillopt.rb) | `arm64_tahoe` · `0.2.0` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/skillopt-0.2.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz) · [`11efed20de60…`](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:11efed20de6048f9469c141c6ceecea2847bdd67b41e113b37eafbc986f8f153) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_tahoe.bottle.2.tar.gz.cdx.json) |
| [`skillopt`](Formula/skillopt.rb) | `arm64_linux` · `0.2.0` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/skillopt-0.2.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz) · [`c09040f4468b…`](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:c09040f4468b3d0bf420f77e2d90d65d3a2584e1fd8938a54c9bddc831af134b) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.arm64_linux.bottle.2.tar.gz.cdx.json) |
| [`skillopt`](Formula/skillopt.rb) | `x86_64_linux` · `0.2.0` (rebuild 2) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/skillopt-0.2.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz) · [`2f09aef2891b…`](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:2f09aef2891bbfcad8dcd5773c7ff9fc3b6b06c94729aa932c35cb28f86101a5) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/skillopt-0.2.0/skillopt-0.2.0.x86_64_linux.bottle.2.tar.gz.cdx.json) |
| [`skillprism`](Formula/skillprism.rb) | `arm64_tahoe` · `0.5.0` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/skillprism-0.5.0) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz) · [`bc2d0a115955…`](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:bc2d0a11595523e14ffd7ae94202485d47ba5199355f9febfb3f32a68c24fd56) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.5.0/skillprism-0.5.0.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`tgrep`](Formula/tgrep.rb) | `arm64_tahoe` · `1.2.7` | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/tgrep-1.2.7) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz) · [`718b1691a9b7…`](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:718b1691a9b773922513479892c527484a738f3b0601385c080da6e6dec62d10) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.7/tgrep-1.2.7.arm64_tahoe.bottle.tar.gz.cdx.json) |
| [`tree-sitter-java-valhalla`](Formula/tree-sitter-java-valhalla.rb) | `arm64_tahoe` · `0.23.5` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/tree-sitter-java-valhalla-0.23.5) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz) · [`b9eb087611d5…`](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:b9eb087611d5596ce5aa84d932fea7c7db8f6f360aff709310d216ca0cfa85d3) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_tahoe.bottle.1.tar.gz.cdx.json) |
| [`tree-sitter-java-valhalla`](Formula/tree-sitter-java-valhalla.rb) | `arm64_linux` · `0.23.5` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/tree-sitter-java-valhalla-0.23.5) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz) · [`1a479854f137…`](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:1a479854f1373430240636495725997e7af1601900702bc45c477634367c5072) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.arm64_linux.bottle.1.tar.gz.cdx.json) |
| [`tree-sitter-java-valhalla`](Formula/tree-sitter-java-valhalla.rb) | `x86_64_linux` · `0.23.5` (rebuild 1) | [Release](https://github.com/artagon/homebrew-aitools/releases/tag/tree-sitter-java-valhalla-0.23.5) · [Bottle](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz) · [`86bd920213ac…`](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz.sha256) | [SLSA v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz.intoto.jsonl) · [Lineage v1](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz.lineage.intoto.jsonl) · [Sigstore](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz.sigstore.json) · [Summary](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz.provenance.json) · [API Proof](https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:86bd920213aca579f69607e4ed9ef324068373a1b0a6d3af18e50ca960aa2c17) | [SPDX 2.3](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz.spdx.json) · [SPDX Sig](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz.spdx.sigstore.json) · [CycloneDX 1.6](https://github.com/artagon/homebrew-aitools/releases/download/tree-sitter-java-valhalla-0.23.5/tree-sitter-java-valhalla-0.23.5.x86_64_linux.bottle.1.tar.gz.cdx.json) |
<!-- END BOTTLE_PROVENANCE_TABLE -->

### 1. Native Homebrew verification

Enable Homebrew's built-in attestation verification (requires `gh` authenticated to `github.com` or `HOMEBREW_GITHUB_API_TOKEN`):

```sh
HOMEBREW_VERIFY_ATTESTATIONS=1 brew install artagon/aitools/ripwire
brew verify --bottle-tag=arm64_tahoe artagon/aitools/ripwire
brew verify --bottle-tag=x86_64_linux artagon/aitools/ripwire
brew verify --bottle-tag=arm64_linux artagon/aitools/ripwire
```

### 2. Strict multi-layer & air-gapped verification (`scripts/verify-provenance.sh`)

[`scripts/verify-provenance.sh`](scripts/verify-provenance.sh) enforces the exact signer SAN (`...@refs/heads/main`), `--source-ref refs/heads/main`, `--deny-self-hosted-runners`, atomic `--` + `-` dual-subject binding, signed `bottle-lineage/v1` SBOM digests, and Sigstore `cosign` v3 bundles:

```sh
# Online check for one formula or all bottled formulae across all bottle tags:
./scripts/verify-provenance.sh --all-tags ripwire
./scripts/verify-provenance.sh --all --all-tags --require-cosign --homebrew

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
- Source-built formulae (`tree-sitter-java-valhalla`, `ast-grep-valhalla`, `ripwire`, `hashline`, `basic-memory`, `hindsight`, `qmd`, `squeez`, `adrkit`, `nats`, `skillfile`, `skillprism`, `waza`, `skillopt`) attest compilation in `tests.yml` on GitHub-hosted `macos-26` (`arm64_tahoe`), `ubuntu-24.04-arm` (`arm64_linux`), and `ubuntu-24.04` (`x86_64_linux`) runners; upstream-binary formulae (`tgrep`, `ck`, `fff-mcp`, `agent-mail`, `br`, `bd`, `bv`, `herdr`, `agentsync`) attest bottle packaging of the SHA-256-pinned upstream release asset.
- Go binaries (`bd`, `bv`, `nats`, `tgrep`, `waza`), Python wheel metadata (`basic-memory`, `skillopt`), Node `package.json` inventories (`hindsight`, `qmd`), and `cargo-auditable` Rust binaries expose full package inventories to `syft`, whereas standard Rust/C/C++ binaries without embedded audit metadata and `adrkit` (`bun` single-file JS bundle) expose bottle archive and manifest files only.

## Validation

See [integration and provenance tests](tests/README.md) for isolated `bats-core` 1.14+ checks under stock macOS `/bin/bash` 3.2 and modern Bash 5+:
- [`tests/integration_agent_install.bats`](tests/integration_agent_install.bats) exercises both Ripwire activation entrypoints and opt-in hook registration against the real bundled payload in temporary agent homes.
- [`tests/verify_provenance.bats`](tests/verify_provenance.bats) exercises `scripts/verify-provenance.sh`, `scripts/update-readme-bottles.sh`, and `scripts/ci/*` across all bottled formulae, online and air-gapped offline bundles, tamper rejection, and isolated `--homebrew` verification without touching live user state.
