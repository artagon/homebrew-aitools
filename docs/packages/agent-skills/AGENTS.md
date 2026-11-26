# `agent-skills` (`artagon/aitools/agent-skills`) — Agent Guide

- **Kind:** Homebrew Formula (`Formula/agent-skills.rb`)
- **Upstream:** `https://github.com/addyosmani/agent-skills` (`MIT`)
- **Binary:** `addy-agent-skills` (read-only path/catalog inspector)
- **Passive assets:** `$(brew --prefix agent-skills)/share/agent-skills/`
  - `skills/` — 26 SDLC workflow skills (`spec-driven-development`, `test-driven-development`, `code-review-and-quality`, etc.)
  - `agents/` — 5 specialist review personas
  - `references/` — 7 shared engineering checklists (`definition-of-done.md`, etc.)
  - `commands/` — 10 TOML lifecycle commands (`/spec`, `/plan`, `/build`, `/test`, `/review`, `/ship`, etc.)
  - `hooks/` — Session hooks (staged passively, **never activated** on install)
  - `.claude-plugin/`, `.codex-plugin/`, `.agents/`, `.claude/`, `.gemini/`, `.opencode/`, `plugin.json`
  - `apm/agent-skills/` — Self-contained, symlink-free OpenAPM package (`apm.yml` + `skills/`)

## Configuration Paths & State

- **Runtime state:** None. Pure read-only static skill/plugin catalog in the Homebrew Cellar.
- **Environment variables:** `DO_NOT_TRACK=1` exported by `addy-agent-skills` wrapper.
- **Per-skill portability caveat (upstream #361):** Installing a single skill directory without the repo-level `references/` folder omits shared pack checklists. Prefer whole-pack activation or OpenAPM/plugin directory loading.

## Defaults: Upstream vs. Tap-Hardened

| Behavior | Upstream Default | Tap (`artagon/aitools`) Default |
| :--- | :--- | :--- |
| Hook activation | Claude plugin activates `hooks/session-start.sh` when enabled | Staged passively under `pkgshare/hooks/`; zero live hooks activated |
| Live agent config edits | `npx skills add` or marketplace install writes `~/.claude`, `~/.agents`, etc. | Zero dotfile writes on install |
| OpenAPM metadata | Not shipped upstream | Synthesized symlink-free `pkgshare/apm/agent-skills/{apm.yml,skills/}` (omitting `targets:` and `apm.lock.yaml`) verified with `apm audit --ci` |

## Opt-In Setup & Agent Rules

1. **Inspect installed skills and paths:**
   ```sh
   addy-agent-skills --list
   addy-agent-skills --path
   addy-agent-skills --skills-path
   addy-agent-skills --apm-path
   ```
2. **Install via `aitools-skills` or OpenAPM (`apm`):**
   ```sh
   aitools-skills sync --formula agent-skills
   apm install -g "$(addy-agent-skills --apm-path)"
   ```
3. **Load as a read-only Claude Code plugin directory (retains `agents/`, `references/`, and commands):**
   ```sh
   claude --plugin-dir "$(addy-agent-skills --path)"
   ```
4. **Upgrade:** `brew upgrade artagon/aitools/agent-skills`.
