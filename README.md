# Homebrew tap for Ripwire

Install [Ripwire v0.5.0](https://github.com/redhat-et/ripwire/releases/tag/v0.5.0)
from upstream prebuilt binaries. Supports macOS 14 or later on Apple Silicon
and Intel, and Linux on ARM64 and x86-64 with glibc. Musl is not supported.

```sh
brew install artagon/ripwire/ripwire
ripwire . --for="find the code that handles authentication"
```

Upgrade or uninstall:

```sh
brew upgrade artagon/ripwire/ripwire
brew uninstall ripwire
```

## Optional agent integration

Skills and hooks are bundled under `$(brew --prefix ripwire)/share/ripwire/`.
Homebrew install and upgrade do not change agent configuration or shell profiles.

Activate skills for Claude Code:

```sh
bash "$(brew --prefix ripwire)/share/ripwire/skills/install.sh" --claude
```

Activate skills for Codex:

```sh
bash "$(brew --prefix ripwire)/share/ripwire/skills/install.sh" --codex
```

The installer links skills into `~/.claude/skills` for Claude Code or
`${AGENTS_HOME:-$HOME/.agents}/skills` for Codex. Rerun the relevant activation
command after upgrades to refresh added and removed skills.

To also register the optional hooks, install `jq` and run the command for your
client:

```sh
brew install jq
bash "$(brew --prefix ripwire)/share/ripwire/skills/install.sh" --claude --hook
```

```sh
bash "$(brew --prefix ripwire)/share/ripwire/skills/install.sh" --codex --hook
```

`--hook` explicitly changes `~/.claude/settings.json` or
`${CODEX_HOME:-$HOME/.codex}/hooks.json`. For Codex, review and trust the installed
hooks through `/hooks`. The upstream hooks can record local usage data under
`~/.ripwire`; review the bundled scripts before enabling them.

Uninstalling the formula does not undo these opt-in changes. Remove the Ripwire
skill links, `.ripwire-manifest-v1`, and Ripwire hook entries from the selected
client's configuration if you no longer want the integration.
