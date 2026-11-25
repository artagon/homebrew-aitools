# `open-design` (`artagon/aitools/open-design`) — Agent Guide

- **Kind:** Homebrew macOS Cask (`Casks/open-design.rb`)
- **Upstream:** `https://github.com/nexu-io/open-design` (`Apache-2.0`)
- **App bundle:** `Open Design.app` (`io.open-design.desktop`, Apple Silicon + Intel, macOS 12+)

## Configuration Paths & State

- **App data & local projects:** `~/Library/Application Support/Open Design` (local-first; projects, generated files, and BYOK API keys stay local).
- **Logs & caches:** `~/Library/Logs/Open Design`, `~/Library/Caches/io.open-design.desktop`, `~/Library/Preferences/io.open-design.desktop.plist`.
- **macOS `UserDefaults`:** Upstream app does **not** use Sparkle or macOS `UserDefaults` for updater or analytics settings.
- **Updater environment variables (`apps/desktop/src/main/updater/config.ts`):**
  - `OD_UPDATE_ENABLED=0` — Disable custom updater completely (default: `true` in packaged builds, checks `https://releases.open-design.ai/stable/latest/metadata.json` every 6h after a 5s initial delay).
  - `OD_UPDATE_AUTO_CHECK=0` — Disable automatic update polling.
  - `OD_UPDATE_AUTO_DOWNLOAD=0` — Disable automatic update downloads (upstream default: `true`).
  - `OD_UPDATE_AUTO_OPEN=0` — Do not auto-open downloaded installers (upstream default: `false`).

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Behavior |
| :--- | :--- | :--- |
| In-app updater | Custom Electron/Node updater enabled (`releases.open-design.ai`) | `auto_updates true` omitted; caveats document `OD_UPDATE_ENABLED=0` / `OD_UPDATE_AUTO_CHECK=0` |
| Product analytics (PostHog + Langfuse relay) | **On by default** (opt-out via first-run **Don't share** banner or **Settings -> Privacy**) | Disclosed in caveats; cannot be pre-disabled via `UserDefaults` |
| Safety/reliability crash telemetry (PostHog) | **Always enabled** in upstream signed release builds (scrubbed paths/tokens; not toggled by Privacy switch) | Disclosed in caveats (see upstream `PRIVACY.md`) |
| Live coding-agent dotfile edits | None on cask install | Zero edits on `brew install --cask` |

## Opt-In Setup & Agent Rules

1. **Install & upgrade:**
   ```sh
   brew install --cask artagon/aitools/open-design
   brew upgrade --cask artagon/aitools/open-design
   ```
2. **Launch with in-app updates suppressed (bundled hardened CLI launcher):**
   ```sh
   open-design
   # Or explicitly:
   OD_UPDATE_ENABLED=0 OD_UPDATE_AUTO_CHECK=0 OD_UPDATE_AUTO_DOWNLOAD=0 open -a "Open Design"
   ```
3. **Privacy hardening on first launch:** Select **Don't share** on the first-run banner (or toggle off **Anonymous metrics** and **Conversation and tool content** under **Settings -> Privacy**). Note that scrubbed crash/safety telemetry remains active in upstream release builds (`PRIVACY.md`).
4. **BYOK credentials:** API keys are stored locally and never included in telemetry payloads; avoid sharing sensitive secrets inside conversation content if optional analytics are enabled.
