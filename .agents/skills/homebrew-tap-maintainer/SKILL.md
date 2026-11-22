---
name: homebrew-tap-maintainer
description: Author, harden, audit, and publish Homebrew formulae and macOS casks in artagon/aitools. Use when adding or updating Formula/*.rb or Casks/*.rb, troubleshooting brew style/audit/livecheck/test-bot, configuring wrapper or postflight_steps hardening, or running SLSA/Sigstore bottle publishing.
---

# Homebrew Tap Maintainer

Skill marker: `artagon-aitools/homebrew-tap-maintainer/v1`.

Maintain formulae, macOS casks, Bash wrappers, provenance scripts, and release workflows without mutating live coding-agent, shell, or user dotfile configurations. Read [provenance-and-ci.md](references/provenance-and-ci.md) before touching `.github/workflows/`, `scripts/ci/`, `scripts/verify-provenance.sh`, or `bottle do` blocks.

## Formula Authoring & Hardening Checklist

1. **Naming & qualification**:
   - Use fully qualified `artagon/aitools/<formula>` names in `caveats` and installation examples.
   - Declare `conflicts_with` only when a differently named formula installs overlapping executables in `bin/` or `sbin/`, never on same-named formulae across taps.
2. **Literal URLs, checksums, & `livecheck`**:
   - Every formula requires a direct class-body `livecheck do ... end` block.
   - Keep every `url "..."` literal-versioned (never `#{version}`) followed immediately by `sha256 "<64-lowercase-hex>"` (or `version "<X.Y.Z>"` then `sha256 "<64-lowercase-hex>"`) with no trailing comment so `scripts/autobump.sh` rewrites single-URL, multi-platform, and `resource` stanzas uniformly.
   - Place `version "<X.Y.Z>"` between `url` and `sha256` (`brew style` `ComponentsOrder`) only when Homebrew cannot scan the version from `url`; omit `version` on `%40scope%2Fpkg%40X.Y.Z` URLs (`brew audit` rejects redundant `version` stanzas, and `verify-provenance.sh` parses `%40...%40` tags directly).
3. **Licenses**:
   - Use standard SPDX identifiers where representable.
   - When an upstream license adds a custom non-SPDX rider, declare `license :cannot_represent` and run `prefix.install "LICENSE"` (plus any required notice files).
4. **Non-invasive wrappers, permissions, & local-first defaults**:
   - `brew install`, `upgrade`, and `uninstall` must never modify `~/.claude*`, `~/.codex*`, `~/.gemini*`, `~/.config/*`, `~/.hammerspoon`, shell profiles, `~/.homebrew/trust.json`, or `~/.sigstore` (cask `postflight_steps` may write only the app's own `UserDefaults` and guarded single-UTI LaunchServices defaults, opt-out via `HOMEBREW_*_SKIP_DEFAULTS=1`).
   - Stage bundled skills, guides, hooks, and plugins passively under `pkgshare` (`#{opt_pkgshare}/skills`, `#{opt_pkgshare}/plugins`).
   - Run `chmod 0755` on bare uncompressed binaries staged into `libexec/` (`Cleaner#clean` fixes permissions only in `bin/`, `sbin/`, and `lib/`).
   - Disable startup update checks, telemetry, analytics, and unsolicited cloud or paid-API routing in builds and wrappers (`*_NO_UPDATE_CHECK=1`, `*_DISABLE_TELEMETRY=true`, `DO_NOT_TRACK=1`), stop wrapper option parsing at `--`, default local servers/collectors to loopback (`127.0.0.1`), block in-place self-updaters (`exit 2`), and warn against self-updaters in `caveats`.
5. **Cross-platform Python (`uv`), Node, Go, Rust, & C/C++ builds**:
   - In `uv` formulae (`python@3.13` on Linux, managed `3.13` on macOS), pass `"--python", python_arg` and a fixed `"--exclude-newer", "<RFC3339>"` cutoff to both `uv build` and `uv tool install`, and remove upstream `.python-version` files before building.
   - Remove `direct_url.json` and `uv-receipt.toml` from `libexec/tools`, prune foreign-OS/CPU prebuilt libraries (`prebuilds/*`, `pydevd_attach_to_process/*`), normalize macOS wheel `.dylib` IDs to `@rpath/` with `preserve_rpath`, and add Linux `patchelf` + `zlib-ng-compat` only when a bundled shared object links `libz.so.1`.
   - When changing a build-time grammar or source dependency installed under `pkgshare`, bump `revision` on the dependency and all compile-time consumers together.

## Cask Authoring & Hardening Checklist

1. **DSL layout, qualification, `conflicts_with`, & upgrade ownership**:
   - Follow `brew style` Cask stanza order (`version`, `sha256`, `url` with `#{version}`, `name`, `desc`, `homepage`, `livecheck`).
   - Use fully qualified `artagon/aitools/<cask>` names with `--cask` in `caveats` and install/upgrade examples.
   - Declare `conflicts_with cask:` only for differently named casks, never for same-named casks across taps.
   - Omit `auto_updates true` when disabling Sparkle or in-app auto-updates by default so `brew upgrade` retains upgrade ownership.
2. **Sandboxed `postflight_steps` & default hardening**:
   - Use Homebrew 5.x `postflight_steps` (never deprecated `postflight`) with `run "/bin/bash"`, `args: ["-euo", "pipefail", "-c", <<~'SH', ...]`, explicit `writable_paths` (`Library/Preferences`, plus `Library/Containers/<bundle-id>/Data/Library/Preferences` for sandboxed apps), `writable_base: :home`, and `must_succeed: false`.
   - Disable Sparkle auto-updates (`SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, `SUSendProfileInfo = false`; `SUHasLaunchedBefore = true`) and app telemetry/crash reporting by default, checking each write independently so one failure does not abort remaining writes.
   - Never edit user dotfiles (`~/.config/*`, `~/.hammerspoon`, coding-agent configs, shell profiles, `~/.homebrew/trust.json`, or `~/.sigstore`) in `postflight_steps`; reserve user-config cleanup for `zap trash:`.
3. **`HOMEBREW_*` install-time override flags**:
   - Expose overrides exclusively through `HOMEBREW_*` variables (`brew` strips non-`HOMEBREW_*` vars), with per-cask `HOMEBREW_<CASK>_*` taking precedence over tap-wide `HOMEBREW_AITOOLS_*` (`SKIP_DEFAULTS`, `AUTO_UPDATES`, `TELEMETRY`, `SET_DEFAULT`).
   - Trim whitespace in Bash 3.2 `env_bool` so blank per-cask values fall back to tap-wide values, accept only case-insensitive `1`/`true`/`yes`/`on` and `0`/`false`/`no`/`off` (fail closed to `false` with a stderr warning on invalid values), and document every supported flag in `caveats`.
4. **LaunchServices default-handler registration (`duti`)**:
   - Depend on `formula: "duti"`, pass `"{{HOMEBREW_PREFIX}}"` as a positional argument (`"_", "{{HOMEBREW_PREFIX}}"`), resolve an executable file (`[ -f ] && [ -x ]`), probe at most one canonical UTI, trim `duti -d` output, skip `duti -s` when already set or on `duti -d` error (`>= 2`), and never loop or batch `duti -s`.
   - Skip `duti` registration whenever `CI` is truthy unless `HOMEBREW_<CASK>_SET_DEFAULT=1` (or `HOMEBREW_AITOOLS_SET_DEFAULT=1`) explicitly overrides it.
5. **Delivery & Bats coverage**:
   - Casks are not bottled and are excluded from `scripts/autobump.sh` (`--formula` only) and `publish.yml`; keep `tests/cask_postflight_defaults.bats` updated and passing across `/bin/bash` 3.2 and Bash 5+ for every cask with `postflight_steps`.

## Shell & Static Analysis Rules

- Target macOS `/bin/bash` `3.2` with `set -euo pipefail`. Keep arrays non-empty before `"${arr[@]}"` expansion (or use `${arr[@]+"${arr[@]}"}`), and never use `mapfile`, `readarray`, `declare -A`, or `local -n`.
- Repository `scripts/**/*.sh` follow `brew style` (`Homebrew/utils/shfmt.sh` with `then`/`do` on separate lines and `shellcheck --enable=all` requiring `${var}` braces). **Never** run `shellharden --replace` or `shfmt -bn` on `scripts/**/*.sh`.

## Local Verification Gate

Run in an isolated Homebrew config prefix (`USER="$(id -un)" XDG_CONFIG_HOME="$TMP_XDG" HOMEBREW_USER_CONFIG_HOME="$TMP_XDG/homebrew"`):

```sh
rtk brew style Formula/<name>.rb Casks/<cask>.rb scripts/*.sh scripts/ci/*.sh
rtk brew audit --strict --online artagon/aitools/<name>
rtk brew audit --cask --strict --online artagon/aitools/<cask>
rtk brew livecheck artagon/aitools/<name>
rtk brew livecheck --cask artagon/aitools/<cask>
scripts/autobump.sh rewrite Formula/<name>.rb <old_ver> <new_ver>
ast-grep test --config sgconfig.yml
ast-grep scan --config sgconfig.yml . .github/workflows
BATS_BASH32=/bin/bash BATS_MODERN_BASH="$(brew --prefix)/bin/bash" rtk proxy bats --tap tests/verify_provenance.bats
BATS_BASH32=/bin/bash BATS_MODERN_BASH="$(brew --prefix)/bin/bash" rtk proxy bats --tap tests/cask_postflight_defaults.bats
```
