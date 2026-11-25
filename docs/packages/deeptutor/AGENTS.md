# `deeptutor` (`artagon/aitools/deeptutor`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/deeptutor.rb`) **and** macOS Cask (`Casks/deeptutor.rb`)
- **Upstream:** `https://github.com/HKUDS/DeepTutor` (`Apache-2.0` + `THIRD_PARTY_NOTICES.md`)
- **Formula binary:** `deeptutor` (lightweight core CLI/SDK: `chat`, `ask_questions`, `init`, `config`, `doctor`, `session`, `workspace`, `skill`, `plugin`, `module`)
- **Cask app:** `Open DeepTutor.app` (`org.deeptutor.open-desktop`, signed & notarized Electron app with bundled local Python + Node Web UI, Apple Silicon + Intel, macOS 13+)
- **Passive assets (Formula):**
  - Skill: `$(brew --prefix deeptutor)/share/deeptutor/skills/deeptutor-cli/SKILL.md`
  - OpenAPM package: `$(brew --prefix deeptutor)/share/deeptutor/apm/{apm.yml,apm.lock.yaml,skills/}`

## Configuration Paths & State

- **Workspace home:** Controlled by `DEEPTUTOR_HOME` or `--home <path>` (settings stored under `<DEEPTUTOR_HOME>/data/user/settings/`, e.g. `system.json`, LLM/embedding/search profiles). **Always pass `--home` or set `DEEPTUTOR_HOME`** so commands do not create `./data/` in the current repository!
- **System defaults (`deeptutor/services/config/runtime_settings.py`):**
  - `backend_port`: `8001`, `frontend_port`: `3782`, `backend_workers`: `1`
  - `web_fetch_backend`: `"local"` (`DEEPTUTOR_FETCH_BACKEND` overrides)
  - `sandbox_allow_subprocess`: `true` (restricted subprocess execution for office/doc tools; set `false` to disable host-side exec)
  - `capability_routing_enabled`: `false`
  - `security_guard.enabled`: `false` (opt-in rate limiting)
- **Cask data paths:** `~/Library/Application Support/Open DeepTutor`, `~/Library/Logs/`, `~/Library/Preferences/org.deeptutor.open-desktop.plist` (does not use Sparkle or macOS `UserDefaults`).

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| `deeptutor serve` / launcher bind host | `0.0.0.0` (all interfaces) | **Patched to `127.0.0.1`** in source AND injected by wrapper unless `--host` is explicitly given |
| Startup version check | `version_check_enabled: True` | **Patched to `False`** in source AND `DEEPTUTOR_VERSION_CHECK_ENABLED=false` in wrapper |
| In-app automatic updates (`app_update.py`) | Enabled for non-editable wheels | **Patched to `automatic_update=False`** (`brew upgrade artagon/aitools/deeptutor`); wrapper blocks `update`/`self-update`/`upgrade` (`exit 2`) |
| Telemetry | `NEXT_TELEMETRY_DISABLED` unset in CLI | Wrapper sets `DO_NOT_TRACK=1` and `NEXT_TELEMETRY_DISABLED=1` |
| `deeptutor --version` / `-V` | Missing in upstream Typer CLI | Implemented by wrapper (preserving `skill publish --version`) |
| Cask updater & telemetry | Manual Ed25519-signed bundle import only, `127.0.0.1`, zero telemetry | `auto_updates true` omitted; upgrade via `brew upgrade --cask artagon/aitools/deeptutor` |

## Opt-In Setup & Agent Rules

1. **Always set `DEEPTUTOR_HOME` (or `--home`)** before running `init`, `config`, `chat`, or `run` so `./data/` is never created in a Git workspace:
   ```sh
   export DEEPTUTOR_HOME="$HOME/.local/share/deeptutor"
   deeptutor init --non-interactive --home "$DEEPTUTOR_HOME"
   deeptutor config providers
   deeptutor config show --home "$DEEPTUTOR_HOME"
   ```
2. **Never place literal API keys in setup JSON:** Reference environment variable names via `api_key_env` in `setup.json` and validate with `deeptutor config apply setup.json --check` before applying.
3. **Full Web UI vs. CLI:** The formula ships the lightweight core wheel (no torch/CUDA/FAISS/Node bloat). For the full desktop Web UI on macOS, install `brew install --cask artagon/aitools/deeptutor`.
4. **Install skill via OpenAPM:** `apm install "$(brew --prefix deeptutor)/share/deeptutor/apm" --target agent-skills`.
