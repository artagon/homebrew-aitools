# Package Configuration & `AGENTS.md` Guides

Each guide below gives AI coding agents and operators the exact config file paths, environment variables, upstream defaults vs. `artagon/aitools` tap-hardened defaults, network/telemetry posture, opt-in activation commands, and caveats for each packaged tool.

Formula packages also install a local copy at `$(brew --prefix <formula>)/share/doc/<formula>/AGENTS.md`. Published 3-OS formula bottles (`arm64_tahoe`, `arm64_linux`, `x86_64_linux`) carry SLSA v1 and Sigstore provenance verifiable via `HOMEBREW_VERIFY_ATTESTATIONS=1` or [`scripts/verify-provenance.sh`](../../scripts/verify-provenance.sh).

| Package | Kind | Domain | Guide |
| :--- | :--- | :--- | :--- |
| `agency-agents` | Formula + Cask | 4 (Skills/Personas) · 8 (macOS Casks) | [`docs/packages/agency-agents/AGENTS.md`](agency-agents/AGENTS.md) |
| `agent-skills` | Formula | 4 (Skills/Personas) | [`docs/packages/agent-skills/AGENTS.md`](agent-skills/AGENTS.md) |
| `agent-tincan` | Formula | 3 (Multi-Agent Messaging) | [`docs/packages/agent-tincan/AGENTS.md`](agent-tincan/AGENTS.md) |
| `deeptutor` | Formula + Cask | 6 (AI Companions) · 8 (macOS Casks) | [`docs/packages/deeptutor/AGENTS.md`](deeptutor/AGENTS.md) |
| `diagram-design` | Formula | 4 (Design Intelligence) | [`docs/packages/diagram-design/AGENTS.md`](diagram-design/AGENTS.md) |
| `open-design` | Cask | 8 (macOS Casks) | [`docs/packages/open-design/AGENTS.md`](open-design/AGENTS.md) |
| `openviking` | Formula | 2 (Memory & Context DBs) | [`docs/packages/openviking/AGENTS.md`](openviking/AGENTS.md) |
| `paperclip` | Formula | 3 (Multi-Agent Orchestration) | [`docs/packages/paperclip/AGENTS.md`](paperclip/AGENTS.md) |
| `printing-press-library` | Formula | 4 (CLI Catalogs) | [`docs/packages/printing-press-library/AGENTS.md`](printing-press-library/AGENTS.md) |
| `ui-ux-pro-max-cli` | Formula | 4 (Design Intelligence) | [`docs/packages/ui-ux-pro-max-cli/AGENTS.md`](ui-ux-pro-max-cli/AGENTS.md) |

For offline inspection after installing any formula, read `$(brew --prefix <formula>)/share/doc/<formula>/AGENTS.md` or run `brew info artagon/aitools/<formula>`.

For tap-wide hardening, bottle provenance, and maintenance invariants, see [`docs/agent-context.md`](../agent-context.md).
