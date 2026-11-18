# Tap maintenance

- Keep formula-generated (`ripwire-agent-install`) and standalone (`scripts/install-agent-skills.sh`) agent installer behavior aligned.
- Support macOS `/bin/bash` 3.2 with `set -euo pipefail`. Keep argument arrays nonempty before expansion and avoid Bash 4+ builtins (`mapfile`, `readarray`, `declare -A`, `local -n`).
- Follow `brew style` (`Homebrew/utils/shfmt.sh` separate-line `then`/`do` and `shellcheck --enable=all` `${var}` braces) across `scripts/**/*.sh`; never run `shellharden --replace` or `shfmt -bn` on `scripts/**/*.sh`.
- Use fully qualified `artagon/aitools/<formula>` names in `caveats` and installation examples.
- Bump `revision` when changing installed files without an upstream version bump, and bump `tree-sitter-java-valhalla`, `ast-grep-valhalla`, and `ripwire` together when the [Java grammar patch](docs/agent-context.md#java-grammar-patch) changes.
- Give every formula a direct `livecheck` block and keep every `url "..."` literal-versioned (never `#{version}`) followed immediately by `sha256 "<64-hex>"` (or `version "..."` then `sha256 "<64-hex>"` for scoped tags) with no trailing comment (`scripts/autobump.sh`).
- Disable upstream startup update checks, telemetry, analytics, and unsolicited cloud routing in wrappers and builds, bind local servers/CLIs to loopback (`127.0.0.1`) by default, block in-place self-updaters (`exit 2`), and warn against self-updaters in `caveats`; see [Maintenance context](docs/agent-context.md).
- Declare `license :cannot_represent` and run `prefix.install "LICENSE"` when an upstream license adds a custom non-SPDX rider.
- Declare `conflicts_with` only when a differently named formula installs overlapping binaries (`ast-grep`, `beads`, `beads_viewer`, `adr-tools`, `cln`, `pi-coding-agent`), never on same-named formulae across taps (`tgrep`, `nats`, `herdr`).
- Land formula changes through `publish.yml` (`brew pr-pull`), never a direct merge, and keep `.github/workflows/sign-bottles.yml@refs/heads/main` as the sole OIDC signing workflow binding both `--` and `-` bottle subjects; see [Bottles](docs/agent-context.md#bottles) and [Build provenance](docs/agent-context.md#build-provenance).
- Exercise both installer entrypoints in isolated homes, and run `bats --tap tests/verify_provenance.bats` across `/bin/bash` 3.2 and Bash 5+ when changing provenance scripts, workflows, or bottle conventions.
- Never activate hooks or modify live agent, Homebrew trust (`~/.homebrew/trust.json`), or Sigstore (`~/.sigstore`) configuration during installs or tests.
- Run `ast-grep test --config sgconfig.yml` and `ast-grep scan --config sgconfig.yml . .github/workflows` after changing formulae, shell scripts, workflows, or rules; see [ast-grep checks](docs/ast-grep.md).

See [project overview](ABOUT.md), [tooling & boundaries](TOOLS.md), [integration tests](tests/README.md), [maintenance context](docs/agent-context.md), and the project skill [homebrew-tap-maintainer](.agents/skills/homebrew-tap-maintainer/SKILL.md).
