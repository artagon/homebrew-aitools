# `agency-agents` (`artagon/aitools/agency-agents`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/agency-agents.rb`) **and** macOS Cask (`Casks/agency-agents.rb`)
- **Upstreams:** `msitarzewski/agency-agents` (catalog, `MIT`, untagged commit-pinned) and `msitarzewski/agency-agents-app` (Tauri desktop app, `MIT`, macOS 13+)
- **Formula binaries:** `agency-agents`, `agency-agents-install`, `agency-agents-convert`
- **Cask app:** `Agency Agents.app` (`com.zerologic.agency-agents-app`)
- **Passive catalog:** `$(brew --prefix agency-agents)/share/agency-agents/` (`divisions.json`, `tools.json`, 18 persona divisions, `strategy/`, `examples/`, `scripts/`)

## Configuration Paths & State

- **Formula conversion cache:** `${XDG_CACHE_HOME:-~/.cache}/agency-agents/integrations/<version>` (override via `AGENCY_INTEGRATIONS_DIR` or `--out`). Never writes into the read-only Homebrew Cellar.
- **Formula opt-in targets:** Writes to coding-agent directories (`~/.claude/agents`, `~/.codex`, etc.) **only** when explicitly invoked via `agency-agents-install` (`--path <dir>` overrides target, `--dry-run` previews).
- **Cask settings file:** `~/Library/Application Support/com.zerologic.agency-agents-app/settings.json` (atomic JSON, 1 MiB cap, fail-closed on corruption). Does **not** read macOS `UserDefaults`.
- **Cask key settings defaults (`settings.rs`):**
  - `updateAutoCheck`: `false`
  - `githubEnabled`: `false` (no GitHub API probes unless opted in)
  - `paranoidMode`: `false` (set `true` to block all outbound network calls)
  - `catalogStaleBannerDays`: `14` (clamped `[1, 365]`)
  - `trendingTtlMinutes`: `60` (clamped `[5, 1440]`)
  - `vulnerabilityScanningEnabled`: `false`

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| Formula conversion output dir | Writes into `$REPO_ROOT/integrations` (fails in read-only Cellar) | Patched to `${AGENCY_INTEGRATIONS_DIR}` under XDG cache |
| Formula self-update | None | Wrapper blocks `update`/`self-update`/`upgrade` (`exit 2`), exports `DO_NOT_TRACK=1` |
| Cask in-app updater | Tauri updater (`updateAutoCheck: false` by default) | `auto_updates true` omitted; upgrade via `brew upgrade --cask artagon/aitools/agency-agents` |
| Cask telemetry / crash reports | None | None |
| Live agent dotfile edits | Only on explicit install | Zero edits on `brew install` / `upgrade` |

## Opt-In Setup & Agent Rules

1. **Always qualify tap and kind** because both formula and cask share the name:
   - CLI catalog: `brew install artagon/aitools/agency-agents`
   - Desktop app: `brew install --cask artagon/aitools/agency-agents`
2. **Browse without writing:**
   ```sh
   agency-agents list teams
   agency-agents list tools
   agency-agents path
   ```
3. **Preview before installing personas:**
   ```sh
   agency-agents-install --tool claude-code --division engineering --dry-run
   agency-agents-install --tool claude-code --division research --path ./tmp-agents
   ```
4. **Cask updater safety:** Keep `updateAutoCheck: false` in `Agency Agents.app` Settings so Tauri does not overwrite the Homebrew-managed app bundle.
