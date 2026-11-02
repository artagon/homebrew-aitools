# Artagon AI Tools Homebrew Tap (`artagon/aitools`)

Curated high-performance developer tooling for AI coding agents.

```sh
# Tap this repository once:
brew tap artagon/aitools

# Install tools:
brew install artagon/aitools/ripwire
brew install artagon/aitools/tgrep
brew install artagon/aitools/ast-grep-valhalla
brew install artagon/aitools/ck
brew install artagon/aitools/fff-mcp
```

Use the qualified names to select this tap; Homebrew core also has `tgrep` and `ast-grep` formulas.
You can also install directly without tapping:

```sh
brew install artagon/aitools/ripwire
brew install artagon/aitools/tgrep
brew install artagon/aitools/ast-grep-valhalla
brew install artagon/aitools/ck
brew install artagon/aitools/fff-mcp
```

On Apple Silicon with macOS 26 or later, the formulae install from bottles that the tap's CI
builds and publishes. Elsewhere, `ripwire` and `ast-grep-valhalla` build from source against
`artagon/aitools/tree-sitter-java-valhalla`, so Homebrew installs that grammar first. `tgrep`,
`ck`, and `fff-mcp` install upstream release binaries.

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

## Automatic version updates

[`autobump.yml`](.github/workflows/autobump.yml) runs daily and on demand. Each formula's
`livecheck` block finds the latest upstream release, and
[`scripts/autobump.sh`](scripts/autobump.sh) opens one pull request per new version. The script
moves every versioned URL to the new release and recomputes its SHA-256, so tgrep's per-platform
archives bump the same way as single-archive formulae. A `tree-sitter-java-valhalla` bump also
bumps the `revision` of `ast-grep-valhalla` and `ripwire`, which compile the grammar in.

## Bottles and publishing

Every pull request runs [`tests.yml`](.github/workflows/tests.yml): `brew test-bot` builds, tests,
and bottles the changed formulae on a macOS 26 Apple Silicon runner, and the installer integration
suite runs against the new Ripwire bottle. When it passes, review the diff and publish the
commit you reviewed:

```sh
gh workflow run publish.yml -f pull_request=<number> \
  -f head_sha="$(gh pr view <number> --json headRefOid --jq .headRefOid)"
```

Publishing runs only from `main` and refuses pull requests from forks, pull requests behind
`main`, a head other than the reviewed commit, and commits whose newest test run failed.

[`publish.yml`](.github/workflows/publish.yml) runs `brew pr-pull`. It uploads the bottles to one
GitHub Release per formula version, adds `bottle do` blocks to the formulae, and pushes the result
to `main`. Do not merge formula pull requests directly; the formulae would ship without bottles.

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

## Validation

See [integration tests](tests/README.md) for isolated checks of both activation
entrypoints under Bash 3.2 and modern Bash, including opt-in hook registration.
These tests use the real bundled installer and temporary agent homes.
