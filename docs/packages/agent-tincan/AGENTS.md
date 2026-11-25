# `agent-tincan` (`artagon/aitools/agent-tincan`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/agent-tincan.rb`)
- **Upstream:** `https://github.com/mvanhorn/agent-tincan` (`MIT`)
- **Binaries:** `tincan` (CLI + `tincan mcp` stdio MCP server)
- **Passive assets:** `$(brew --prefix agent-tincan)/share/agent-tincan/{extension,docs}`

## Configuration Paths & State

- **Client config:** `~/.config/tincan/client.json` (or `$XDG_CONFIG_HOME/tincan/client.json`; override per agent via `TINCAN_CONFIG=/path/to/client.json`). Created only on opt-in `tincan join`, mode `0600`.
- **Relay state & admin socket:** Local state directory (`--state-dir`, admin socket `<state-dir>/admin.sock`, SQLite store via pure-Go `modernc.org/sqlite`).
- **Environment variables:**
  - `TS_AUTHKEY` — Tailscale auth key when bootstrapping `tincan relay` (tailnet hostname defaults to `tincan-relay`, reachable at `http://tincan-relay`).
  - `TINCAN_RELAY` — Default relay URL for admin commands (`--relay` overrides).
  - `TINCAN_CONFIG` — Alternate client config file path for multi-agent hosts.
  - `DO_NOT_TRACK` — Exported as `1` by default in the Homebrew wrapper (caller may override).

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| Self-upgrade (`tincan upgrade`, `relay-upgrade`) | Downloads binary from relay/GitHub and replaces in place | **Blocked (`exit 2`)** by wrapper; upgrade via `brew upgrade artagon/aitools/agent-tincan` |
| Telemetry / update checks | None in upstream binary | `DO_NOT_TRACK=1` exported by wrapper |
| Auth model | Tailscale `WhoIs` identity (no inter-agent API keys) | Unchanged |
| macOS Login Items `.app` | Developer-ID-signed `Agent Tincan.app` in upstream release | Omitted in reproducible source build; LaunchAgents invoke `tincan` directly |
| Live agent/browser config edits | None on binary install | Zero live writes on install; Chrome extension staged passively |

## Opt-In Setup & Agent Rules

1. **MCP registration (stdio):**
   ```sh
   claude mcp add --transport stdio --scope user tincan -- "$(brew --prefix)/opt/agent-tincan/bin/tincan" mcp
   ```
2. **Service installs:** Always pass `--binary "$(brew --prefix)/opt/agent-tincan/bin/tincan"` to `tincan relay install` / `tincan listen install` so service paths survive Homebrew upgrades. Do **not** pass `--self-upgrade`.
3. **Offline operator guide:** Run `tincan onboard --offline --section operator` or read `$(brew --prefix agent-tincan)/share/agent-tincan/docs/agents.txt`.
4. **Chrome history extension:** Load unpacked from `$(brew --prefix agent-tincan)/share/agent-tincan/extension`.
5. **Version check command:** Use `tincan version` (not `--version`).
