# Maintenance context

The tap ships pinned upstream binaries and bundled Ripwire skills. Homebrew install
and upgrade must not activate agent integrations. Activation is explicit through
the formula-generated `ripwire-agent-install` or `scripts/install-agent-skills.sh`.

Both entrypoints support stock macOS Bash 3.2. Keep invocation arrays nonempty:
expanding an empty array under `set -u` aborts Bash 3.2. The installer path is the
first element of the argument array; optional flags are appended to it.

Codex detection uses its executable or its own configuration root. The shared
`.agents` root is a fallback destination and does not establish Codex presence.
Antigravity detection also recognizes an existing `AGY_SKILLS_DIR` directory.

Ripwire revision 1 makes the generated activation command available to existing
0.5.0 installations through Homebrew upgrade. The README qualifies formula names
because Homebrew core also contains `tgrep`.

Use [the integration suite](../tests/README.md) to validate wrapper behavior with
real payloads. An extracted Ruby-evaluated wrapper test does not prove Homebrew
installation, upgrade, permissions, or formula-test lifecycle behavior. Verify
those through actual Homebrew commands in an isolated prefix. Archive checksum
verification does not prove execution on another architecture or operating system.
