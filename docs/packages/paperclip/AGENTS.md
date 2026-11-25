# `paperclip` (`artagon/aitools/paperclip`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/paperclip.rb`)
- **Upstream:** `https://github.com/paperclipai/paperclip` (`MIT`, npm `paperclipai`)
- **Binary:** `paperclipai` (Node >= 24.11 server, React UI, embedded PostgreSQL 18, `paperclip-runnerd`)
- **Passive skills:** `$(brew --prefix paperclip)/share/paperclip/skills` (9 skills: `paperclip`, `paperclip-board`, `paperclip-create-agent`, `paperclip-converting-plans-to-tasks`, `agentmail`, `para-memory-files`, `slack`, `complain`, `suggestion-box`)

## Configuration Paths & State

- **Instance home:** `~/.paperclip/instances/default/` (`config.json`, `.env`, embedded PostgreSQL data dir, secrets master key, backups). Override via `PAPERCLIP_HOME` / `PAPERCLIP_INSTANCE_ID` / `PAPERCLIP_CONFIG`.
- **Network & database defaults (`server/src/config.ts`):**
  - Bind mode: `loopback`, host `127.0.0.1`, port `3100` (`PAPERCLIP_BIND`, `HOST`, `PORT`).
  - Database: `embedded-postgres` on port `54329` (override with `DATABASE_URL` for external PostgreSQL).
  - UI serving: `SERVE_UI=true`; heartbeat scheduler interval: `30000` ms (`HEARTBEAT_SCHEDULER_INTERVAL_MS`).
- **Wrapper-enforced environment variables:**
  - `PAPERCLIP_TELEMETRY_DISABLED=1` (**unconditionally forced** by wrapper)
  - `DO_NOT_TRACK=1` (**unconditionally forced** by wrapper)
  - `PAPERCLIP_UPDATE_CHECK=0` (**unconditionally forced** by wrapper)
  - `PAPERCLIP_ANNOUNCEMENTS_ENABLED=false` (defaulted by wrapper; caller may override)

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| Usage telemetry (`telemetry.paperclip.ing`) | **Enabled by default** (and written `enabled: true` by `onboard`) | **Unconditionally disabled** (`PAPERCLIP_TELEMETRY_DISABLED=1`, `DO_NOT_TRACK=1`) |
| Startup npm update notice | Checks `registry.npmjs.org/paperclipai` | **Unconditionally disabled** (`PAPERCLIP_UPDATE_CHECK=0`) |
| Remote announcement banner | Fetches `pages.paperclip.ing/announcements/v1/current.json` | **Disabled by default** (`PAPERCLIP_ANNOUNCEMENTS_ENABLED=false`) |
| Self-updaters (`update`, `upgrade`, `self-update`) | Replaces package in place | **Blocked (`exit 2`)**; upgrade via `brew upgrade artagon/aitools/paperclip` |
| Bind address | Loopback `127.0.0.1:3100` (`local_trusted`) | Preserved (`HOST` is not clobbered so explicit `--bind`/`config.json` overrides still work) |
| Sentry / OpenTelemetry | Opt-in peer deps | Peer SDKs not installed |

## Opt-In Setup & Agent Rules

1. **Non-interactive local onboarding (no service/profile edits):**
   ```sh
   paperclipai onboard --yes --no-install-service
   paperclipai run
   ```
2. **Never run `paperclipai install` or `paperclipai uninstall`:** Those upstream commands create a `~/.paperclip/cli` shadow shim and edit `~/.bashrc`/`~/.zshrc`.
3. **Never run `paperclipai update`/`upgrade`/`self-update`:** Blocked (`exit 2`); use `brew upgrade artagon/aitools/paperclip`.
4. **Linux note:** Codex's optional bundled `zsh` is pruned on Linux for glibc/tinfo bottle compatibility; Codex falls back cleanly to host `sh`/`bash`/`zsh`.
5. **Agent skills:** Symlink or register skills explicitly from `$(brew --prefix paperclip)/share/paperclip/skills`.
