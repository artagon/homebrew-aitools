# Artagon AI Tools Homebrew Tap (`artagon/aitools`)

Curated high-performance developer tooling for AI coding agents.

```sh
# Tap this repository once:
brew tap artagon/aitools

# Install tools:
brew install ripwire
brew install tgrep
```

Or install directly without tapping:

```sh
brew install artagon/aitools/ripwire
brew install artagon/aitools/tgrep
```

---

## ripwire

Install [Ripwire v0.5.0](https://github.com/redhat-et/ripwire/releases/tag/v0.5.0) — Codebase symbol maps and call graphs for AI agents. Supports macOS 14 or later on Apple Silicon and Intel, and Linux on ARM64 and x86-64 with glibc. Musl is not supported.

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
| **Google Antigravity** | `agy` / `~/.gemini` | `~/.gemini/antigravity-cli/skills` | MCP server (`ripwire --mcp`) |
| **Moonshot Kimi** | `kimi` / `~/.kimi-code` | `${KIMI_CODE_HOME:-$HOME/.kimi-code}/skills` | MCP server (`ripwire --mcp`) |
| **Grok CLI** | `grok` / `~/.grok` | `${GROK_HOME:-$HOME/.grok}/skills` | MCP server (`ripwire --mcp`) |
| **GitHub Copilot** | `copilot` / `~/.copilot` | `${COPILOT_HOME:-$HOME/.copilot}/skills` | MCP server (`ripwire --mcp`) |
| **Cross-Agent Shared** | APM / multi-agent | `~/.agents/skills` | Standard discovery root |

### Quickstart (Auto-Detection)

To automatically detect installed CLIs and link skills:

```sh
ripwire-agent-install
```

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

Install [tgrep v1.0.8](https://github.com/microsoft/tgrep/releases/tag/v1.0.8) — Trigram-indexed grep with a client/server architecture for fast regex search in large codebases:

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

