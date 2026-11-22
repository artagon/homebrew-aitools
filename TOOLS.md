# Repository Tooling & Static-Analysis Boundaries

Repository override for `~/.agents/TOOLS.md` covering Homebrew Ruby formulae, Bash 3.2+ scripts, `bats-core` suites, `ast-grep` rules, and GitHub Actions YAML workflows.

## 1. Tool Selection for This Tap

| Task | Primary Tool | Invocation & Repo Rule |
| :--- | :--- | :--- |
| Live text, formula DSL, env vars, prose | `rtk rg` | `rtk rg -n '<pattern>' Formula scripts .github tests docs` |
| Structural lint gates & AST search | `ast-grep` | `ast-grep test --config sgconfig.yml` and `ast-grep scan --config sgconfig.yml . .github/workflows` (explicit `.github/workflows` scans hidden workflow YAML) |
| Script & test call-graph orientation | `ripwire` | `ripwire . --for="<task>" --legend=compact` (`PARTIAL` on `.bats` `@test` blocks, Ruby DSL stanzas, and `ci::*` namespace prefixes — query bare function names) |
| Formula & tap shell style / RuboCop | `brew style` | `rtk brew style Formula/<name>.rb scripts/*.sh scripts/ci/*.sh` (uses `Homebrew/utils/shfmt.sh` and `shellcheck --enable=all`; **never** run `shellharden --replace` or `shfmt -bn` on `scripts/**/*.sh`) |
| Bats & helper static analysis | `shellcheck` + `shfmt` | `rtk shellcheck --shell=bash --severity=info -x tests/helpers/*.bash`, `rtk shellcheck --shell=bats --severity=info -x tests/*.bats`, `rtk shfmt -ln bats -i 2 -d tests/*.bats` |
| Workflow static & security audit | `actionlint` + `zizmor` | `rtk actionlint` and `rtk zizmor --persona=auditor .github/workflows` |
| Bash 3.2 & Bash 5+ behavioral proof | `bats` | `BATS_BASH32=/bin/bash BATS_MODERN_BASH=/opt/homebrew/bin/bash rtk proxy bats --tap tests/verify_provenance.bats` (and `tests/integration_agent_install.bats` when the matching `ripwire` version is installed) |
| Formula audit & upstream version check | `brew` | `rtk brew audit --strict --online artagon/aitools/<name>` and `rtk brew livecheck artagon/aitools/<name>` (in isolated `XDG_CONFIG_HOME` / `HOMEBREW_USER_CONFIG_HOME`) |

### Disabled / Unneeded Heavyweight Indexers

- **`serena` MCP**: `UNAVAILABLE` / intentionally disabled (Homebrew Ruby formulae have no `Gemfile`/LSP project model).
- **Semantic / fuzzy file indexers (`fff-mcp`, `ck`)**: Intentionally omitted from `.mcp-policy.json` (`rtk rg` + `ast-grep` scan the entire repository directly without index staleness or schema overhead).
- **`tgrep`**: Optional (`PARTIAL` unless `.tgrep/` is freshly indexed; prefer `rtk rg`).

## 2. Named Static-Analysis Boundaries

Static call graphs and AST rules stop at six repository boundaries — always cross-check with `rtk rg` and targeted tests:

1. **Embedded Bash wrappers inside Ruby heredocs** (`Formula/*.rb` `(bin/...).write <<~SH` / `<<~SHELL`): Not parsed as Bash by `ast-grep` or `shellcheck` unless extracted (`tests/integration_agent_install.bats` Ruby-evaluates the installer wrapper; verify other wrappers via `/bin/bash -n` and `brew test`).
2. **`scripts/autobump.sh` line-layout contract**: Expects literal version strings in `url "..."`, `sha256 "<64-hex>"` immediately following `url` (or `version "..."` then `sha256 "<64-hex>"`) with no trailing comment, and `  license ...` indentation when inserting `revision 1`. Verify changes with `scripts/autobump.sh rewrite`.
3. **`scripts/ci/verify-patch-policy.sh` diff state machine**: Enforces that `publish.yml` commits modify only `bottle do ... end` statements in `Formula/*.rb` and lines strictly between standalone `<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->` and `<!-- END BOTTLE_PROVENANCE_TABLE -->` markers in `README.md`.
4. **Workflow -> `scripts/ci/` environment & `trusted-scripts` boundary**: `.github/workflows/*.yml` passes inputs exclusively via `env:` into `scripts/ci/*.sh`, and `publish.yml` snapshots `scripts/` from `refs/heads/main` into `${RUNNER_TEMP}/trusted-scripts` before checking out PR commits.
5. **Compile-time grammar & source-inclusion boundary**: Formulae that compile patched grammar or crate sources staged under a dependency's `opt_pkgshare` do not rebuild automatically unless `revision` is bumped across the producer and all consumers together.
6. **Installer payload SHA-256 pin**: `tests/helpers/agent_install_helper.bash` pins the SHA-256 of the bundled skill installer script.

## 3. `SUPPORTED` Evidence Gates

Require `SUPPORTED` evidence (direct source read + matching test/audit execution) before modifying `.github/workflows/sign-bottles.yml`, `.github/workflows/publish.yml`, `scripts/ci/verify-patch-policy.sh`, `scripts/verify-provenance.sh`, or build-time grammar patches, and before claiming any script helper, environment variable, or formula resource is unused.
