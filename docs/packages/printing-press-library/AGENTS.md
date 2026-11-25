# `printing-press-library` (`artagon/aitools/printing-press-library`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/printing-press-library.rb`)
- **Upstream:** `https://github.com/mvanhorn/printing-press-library` (`MIT`, npm `@mvanhorn/printing-press-library`)
- **Binaries:** `printing-press-library`
- **Passive skill:** `$(brew --prefix printing-press-library)/share/printing-press-library/skills/printing-press-library/SKILL.md`

## Configuration Paths & State

- **Catalog source:** Reads live `registry.json` from GitHub at runtime (`--registry-url <url>` overrides for offline/private registries).
- **Installed Go CLI binary dir:** `~/.local/bin` by default (`--bin-dir <dir>` overrides).
- **Installed skills:** Delegates to `npx skills@latest` unless `--cli-only` is passed.
- **Environment variables:**
  - `DO_NOT_TRACK` — Defaulted to `1` by wrapper.
  - `DISABLE_TELEMETRY` — Defaulted to `1` by wrapper (suppresses downstream `npx skills` telemetry).
  - Per-CLI API credentials are scoped to each installed catalog CLI (`pp-*` skill documents required env vars).

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| Package upgrade | `npx @mvanhorn/printing-press-library` | Managed via `brew upgrade artagon/aitools/printing-press-library` |
| `update` / `reinstall` subcommands | Refreshes installed catalog Go CLIs | **Kept enabled** (refreshes catalog CLIs, not this Homebrew package) |
| Telemetry | Downstream `npx skills` telemetry uncontrolled | `DO_NOT_TRACK=1` and `DISABLE_TELEMETRY=1` exported by default |
| Discovery skill activation | Manual `npx skills add` | Staged passively under `pkgshare/skills/printing-press-library/SKILL.md`; zero dotfile edits |

## Opt-In Setup & Agent Rules

1. **Prerequisite for installing Go CLIs:** `go` must be on `PATH` (`brew install go`). Discovery (`list`, `search`) and `--skill-only` do not require Go.
2. **Discover without mutating the system:**
   ```sh
   printing-press-library list --json
   printing-press-library search flights --json
   printing-press-library list --installed --json
   ```
3. **Install safely with explicit scope:**
   - Binary only (no `npx skills` writes): `printing-press-library install <name> --cli-only --bin-dir ~/.local/bin`
   - Skill only (no `go install`): `printing-press-library install <name> --skill-only`
4. **Uninstall:** Requires explicit `--yes` (`printing-press-library uninstall <name> --yes`).
5. **Security note:** Installed catalog CLIs build from pinned `source_commit` hashes in the live `registry.json`; review the target CLI under `library/<category>/<name>` before installing or supplying API credentials.
