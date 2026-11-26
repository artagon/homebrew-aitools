# `ui-ux-pro-max-cli` (`artagon/aitools/ui-ux-pro-max-cli`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/ui-ux-pro-max-cli.rb`)
- **Upstream:** `https://github.com/nextlevelbuilder/ui-ux-pro-max-skill` (`MIT`)
- **Binaries:** `uipro`, `uipro-search`
- **Passive assets:**
  - Skills: `$(brew --prefix ui-ux-pro-max-cli)/share/ui-ux-pro-max-cli/skills` (7 skills: `ui-ux-pro-max`, `banner-design`, `brand`, `design`, `design-system`, `slides`, `ui-styling`)
  - OpenAPM package: `$(brew --prefix ui-ux-pro-max-cli)/share/ui-ux-pro-max-cli/apm/ui-ux-pro-max-cli` (`apm.yml` + real, symlink-free `skills/`)

## Configuration Paths & State

- **Offline design database:** Bundled CSV datasets (`styles.csv`, palettes, typography, UX rules, charts, stacks) inside `$(brew --prefix ui-ux-pro-max-cli)/share/ui-ux-pro-max-cli/apm/ui-ux-pro-max-cli/skills/ui-ux-pro-max/data/`. Runs 100% offline with Homebrew Python 3.13 stdlib.
- **Project skill install targets (opt-in via `uipro init`):** Writes `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, etc. in the current working directory (or `--global` user dir).
- **Environment variables:**
  - `DO_NOT_TRACK=1` — Defaulted in both `uipro` and `uipro-search`.
  - `PYTHONNOUSERSITE=1`, `PYTHONUTF8=1`, `PYTHONDONTWRITEBYTECODE=1` — Defaulted in `uipro-search` so Cellar scripts stay read-only and clean of `__pycache__`.

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| `uipro update` | Runs `npm install -g ui-ux-pro-max-cli@...` | **Blocked (`exit 2`)**; upgrade via `brew upgrade artagon/aitools/ui-ux-pro-max-cli` |
| `uipro --version` | Git tag lagged npm publish version | Synced to formula release version at build time |
| Telemetry | None | `DO_NOT_TRACK=1` exported by default |
| Skill installation | Manual `uipro init` / `npx` | Staged passively + valid symlink-free OpenAPM package (`pkgshare/apm/ui-ux-pro-max-cli/apm.yml`) |

## Opt-In Setup & Agent Rules

1. **Query design intelligence offline (prefer `--json` for agents to avoid 300-char human truncation):**
   ```sh
   uipro-search "fintech dashboard minimal" --domain style --json
   uipro-search "saas analytics dashboard" --design-system --json
   ```
2. **Install via `aitools-skills` or OpenAPM (`apm`):**
   ```sh
   aitools-skills sync --formula ui-ux-pro-max-cli
   apm install -g "$(brew --prefix ui-ux-pro-max-cli)/share/ui-ux-pro-max-cli/apm/ui-ux-pro-max-cli"
   ```
3. **Install into a single project offline via `uipro`:**
   ```sh
   uipro init --ai claude --offline
   ```
4. **Never run `uipro update`** (blocked with `exit 2`). Do not edit files inside `$(brew --prefix ui-ux-pro-max-cli)`.
