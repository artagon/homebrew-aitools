# `diagram-design` (`artagon/aitools/diagram-design`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/diagram-design.rb`)
- **Upstream:** `https://github.com/cathrynlavery/diagram-design` (`MIT`, untagged commit-pinned)
- **Binary:** `diagram-design` (`self-check`, `--list`, `--path`, `--skill-path`, `--apm-path`, `--version`)
- **Passive assets:** `$(brew --prefix diagram-design)/share/diagram-design/`
  - `skills/diagram-design/` (52 diagram type references + stdlib Python helper scripts)
  - `apm/` (self-contained, symlink-free OpenAPM package: `apm.yml` + `apm.lock.yaml` + `skills/diagram-design/`)
  - `commands/`, `prompts/`, `assets/`, `.claude-plugin/`, `.codex-plugin/`, `.factory-plugin/`, `.qoder-plugin/`, `.agents/`

## Configuration Paths & State

- **Brand profiles (optional, user-created):** `~/.diagram-design/profiles/` (never created during install).
- **Runtime helper scripts (`skills/diagram-design/scripts/`):**
  - Stdlib Python 3.13 only: `self_check.py`, `verify_geometry.py`, `export_svg.py`, and draw.io/Mermaid/Excalidraw/PlantUML extractors.
  - Optional Playwright dependency: `export_png.py` and `export_pdf.py` (only needed if rasterizing HTML to PNG/PDF).
- **Wrapper-enforced environment defaults:** `DO_NOT_TRACK=1`, `PYTHONNOUSERSITE=1`, `PYTHONUTF8=1`, `PYTHONDONTWRITEBYTECODE=1`.

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| Server / accounts / telemetry | None (100% local files & scripts) | Unchanged (`DO_NOT_TRACK=1` exported) |
| External font links in HTML templates | Templates link Google Fonts (`fonts.googleapis.com`) with system-font fallbacks | Documented in caveats; use `diagram-design self-check --offline <file>` to enforce zero external requests |
| Self-updaters | None | Wrapper blocks `update`/`self-update` (`exit 2`); upgrade via `brew upgrade artagon/aitools/diagram-design` |
| OpenAPM & plugin staging | Native manifests only | Stages both native manifests (passing `claude plugin validate`) and symlink-free `pkgshare/apm/` (passing `apm audit` & `apm pack`) |

## Opt-In Setup & Agent Rules

1. **Validate generated HTML/SVG diagrams offline before presenting to users:**
   ```sh
   diagram-design self-check --offline path/to/diagram.html
   ```
2. **Inspect bundled diagram types (52 types), commands, and scripts:**
   ```sh
   diagram-design --list
   ```
3. **Activate via OpenAPM or Claude Code plugin directory:**
   ```sh
   apm install "$(diagram-design --apm-path)" --target agent-skills
   claude --plugin-dir "$(diagram-design --path)"
   ```
4. **Offline/air-gapped diagrams:** Omit Google Fonts `<link>` tags so diagrams render with system fonts and pass `--offline` checks with zero network requests.
