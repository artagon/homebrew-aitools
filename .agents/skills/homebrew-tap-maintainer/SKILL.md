---
name: homebrew-tap-maintainer
description: Author, harden, audit, and publish Homebrew formulae in artagon/aitools. Use when adding or updating Formula/*.rb, troubleshooting brew style/audit/livecheck/test-bot, configuring wrapper hardening, or running SLSA/Sigstore bottle publishing.
---

# Homebrew Tap Maintainer (`artagon/aitools`)

Skill marker: `artagon-aitools/homebrew-tap-maintainer/v1`.

Maintain formulae, Bash wrappers, provenance scripts, and release workflows in `artagon/aitools` without mutating live user or agent configurations. Read [provenance-and-ci.md](references/provenance-and-ci.md) before touching `.github/workflows/`, `scripts/ci/`, `scripts/verify-provenance.sh`, or `bottle do` blocks.

## Formula Authoring & Hardening Checklist

1. **Naming & qualification**:
   - Use fully qualified `artagon/aitools/<formula>` names in `caveats` and documentation.
   - Declare `conflicts_with` only when a differently named core formula installs overlapping binaries (`ast-grep`, `beads`, `beads_viewer`, `adr-tools`, `cln`, `pi-coding-agent`), never on same-named formulae (`tgrep`, `nats`, `herdr`).
2. **Literal URLs, checksums, & `livecheck`**:
   - Every formula requires a direct class-body `livecheck do ... end` block.
   - Keep every `url "..."` literal-versioned (never `#{version}`) followed immediately by `sha256 "<64-lowercase-hex>"` (or `version "<X.Y.Z>"` then `sha256 "<64-lowercase-hex>"` for scoped tags) with no trailing comment so `scripts/autobump.sh` rewrites single-URL, multi-platform, and `resource` stanzas uniformly.
   - Place `version "<X.Y.Z>"` between `url` and `sha256` (`brew style` `ComponentsOrder`) when the archive tag uses scoped npm syntax (`@scope/pkg@X.Y.Z` / `%40...%40X.Y.Z`) so `main`'s `verify-provenance.sh` and `Homebrew` agree cleanly.
3. **Licenses**:
   - Use standard SPDX identifiers where valid (`MIT`, `Apache-2.0`, `AGPL-3.0-or-later`, `Elastic-2.0`).
   - When an upstream license adds a custom rider (`MIT License with OpenAI/Anthropic Rider`), declare `license :cannot_represent` and run `prefix.install "LICENSE"`.
4. **Non-invasive wrappers & local-first runtime defaults**:
   - `brew install`, `upgrade`, and `uninstall` must never modify `~/.claude*`, `~/.codex*`, `~/.gemini*`, `~/.config/*`, `~/.homebrew/trust.json`, or `~/.sigstore`.
   - Stage bundled skills/plugins/hooks passively under `pkgshare` (`#{opt_pkgshare}/skills`, `#{opt_pkgshare}/plugins`).
   - Disable startup update checks, telemetry, analytics, and unsolicited cloud routing in wrappers (`HASHLINE_NO_UPDATE_CHECK=1`, `AGENTSYNC_NO_UPDATE_CHECK=1`, `SKILLFILE_NO_UPDATE_NOTIFIER=1`, `WAZA_NO_UPDATE_CHECK=1`, `BD_DISABLE_METRICS=1`, `BASIC_MEMORY_FORCE_LOCAL=true`, `MLFLOW_DISABLE_TELEMETRY=true`, `PHOENIX_TELEMETRY_ENABLED=false`, `PHOENIX_ALLOW_EXTERNAL_RESOURCES=false`, `SCARF_NO_ANALYTICS=true`, `DO_NOT_TRACK=true`, `fff-mcp --no-update-check`), default local servers/CLIs to `127.0.0.1`, block in-place self-updaters (`exit 2`), and warn against self-updaters in `caveats`.
5. **Cross-platform Python (`uv`), Node, Rust, & C/C++ builds**:
   - In `uv` formulae (`python@3.13` on Linux, managed `3.13` on macOS), always pass `"--python", python_arg` to both `uv build` and `uv tool install` (upstream `.python-version` files otherwise fail under `UV_PYTHON_PREFERENCE=only-system` on Linux).
   - Remove `direct_url.json` and `uv-receipt.toml` from `libexec/tools`, prune foreign-OS/CPU prebuilds (`prebuilds/*`, `pydevd_attach_to_process/*`), normalize macOS wheel `.dylib` IDs to `@rpath/` with `preserve_rpath`, and add Linux `patchelf` + `zlib-ng-compat` only when a bundled wheel actually links `libz.so.1`.
   - When `Formula/tree-sitter-java-valhalla.rb` changes, bump `revision` on `tree-sitter-java-valhalla`, `ast-grep-valhalla`, and `ripwire`.

## Shell & Static Analysis Rules

- Target macOS `/bin/bash` `3.2` with `set -euo pipefail`. Keep arrays non-empty before `"${arr[@]}"` expansion (or use `${arr[@]+"${arr[@]}"}`), and never use `mapfile`, `readarray`, `declare -A`, or `local -n`.
- Repository `scripts/**/*.sh` follow `brew style` (`/opt/homebrew/Library/Homebrew/utils/shfmt.sh` with `then`/`do` on separate lines and `shellcheck --enable=all` requiring `${var}` braces). **Never** run `shellharden --replace` or `shfmt -bn` on `scripts/**/*.sh`.

## Local Verification Gate

Run in an isolated Homebrew config prefix (`USER="$(id -un)" XDG_CONFIG_HOME="$TMP_XDG" HOMEBREW_USER_CONFIG_HOME="$TMP_XDG/homebrew"`):

```sh
rtk brew style Formula/<name>.rb scripts/*.sh scripts/ci/*.sh
rtk brew audit --strict --online artagon/aitools/<name>
rtk brew livecheck artagon/aitools/<name>
scripts/autobump.sh rewrite Formula/<name>.rb <old_ver> <new_ver>
ast-grep test --config sgconfig.yml
ast-grep scan --config sgconfig.yml . .github/workflows
BATS_BASH32=/bin/bash BATS_MODERN_BASH=/opt/homebrew/bin/bash rtk bats --tap tests/verify_provenance.bats
```
