# Tap maintenance

- Keep formula-generated and standalone agent installer behavior aligned.
- Support macOS `/bin/bash` 3.2 with nounset enabled. Argument arrays must remain nonempty.
- Use fully qualified `artagon/aitools/` formula names in installation examples.
- Bump the formula revision when changing installed files without changing the upstream version.
- Keep the Java grammar patch additive, and bump every formula that compiles it when it changes;
  see [Java grammar patch](docs/agent-context.md#java-grammar-patch).
- Give every formula a `livecheck` block; `scripts/autobump.sh` opens version bumps, and a
  reviewer updates the pins it leaves alone; see [Version bumps](docs/agent-context.md#version-bumps).
- Keep every `url "..."` literal-versioned (never `#{version}`) with `sha256 "<64-hex>"` on the
  immediately following line and no trailing comment so `scripts/autobump.sh` updates single-URL,
  multi-platform, and `resource` blocks uniformly.
- Disable upstream startup update checks, telemetry, and remote cloud routing where required in
  Homebrew wrappers and builds (`HASHLINE_NO_UPDATE_CHECK=1`, `AGENTSYNC_NO_UPDATE_CHECK=1`,
  `SKILLFILE_NO_UPDATE_NOTIFIER=1`, `WAZA_NO_UPDATE_CHECK=1`, `BASIC_MEMORY_AUTO_UPDATE=false`,
  `BASIC_MEMORY_NO_PROMOS=1`, `BASIC_MEMORY_FORCE_LOCAL=true`; loopback-only `hindsight`;
  conservative `squeez` defaults; `--backend mock` `skillopt-sleep` defaults) and warn against
  in-place self-updaters in `caveats`.
- Use `license :cannot_represent` and install the full upstream `LICENSE` into `prefix` when an
  upstream license includes a non-SPDX custom rider.
- Declare `conflicts_with` only when a differently named formula installs conflicting binaries
  (`ast-grep`, `beads`, `beads_viewer`, `adr-tools`), not for same-named formulae across taps
  (`tgrep`, `nats`, `herdr`).
- Land formula changes through `publish.yml` (`brew pr-pull`), never a direct merge, so bottles
  and provenance sidecars ship with them; see [Bottles](docs/agent-context.md#bottles) and
  [Build provenance](docs/agent-context.md#build-provenance).
- Keep `.github/workflows/sign-bottles.yml` (`@refs/heads/main`) as the sole OIDC signing
  workflow, binding both `--` (`Bottle::Filename#to_s`) and `-` (`Bottle::Filename#url_encode`)
  subjects in one attestation statement; backfill existing releases with `attest.yml`.
- Exercise both installer entrypoints against the real bundled payload in isolated homes, and run
  `tests/test-verify-provenance.sh` across `/bin/bash` 3.2 and Bash 5+ when changing provenance
  scripts, workflows, or bottle conventions.
- Never activate hooks or modify live agent, Homebrew trust (`~/.homebrew/trust.json`), or
  Sigstore (`~/.sigstore`) configuration during tests.
- Keep review packets immutable; rerun affected tests and independent reviews after fixes.

See [project overview](ABOUT.md), [integration tests](tests/README.md), and [maintenance context](docs/agent-context.md).
