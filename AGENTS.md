# Tap maintenance

- Keep formula-generated and standalone agent installer behavior aligned.
- Support macOS `/bin/bash` 3.2 with nounset enabled. Argument arrays must remain nonempty.
- Use fully qualified `artagon/aitools/` formula names in installation examples.
- Bump the formula revision when changing installed files without changing the upstream version.
- Keep the Java grammar patch additive, and bump every formula that compiles it when it changes;
  see [Java grammar patch](docs/agent-context.md#java-grammar-patch).
- Give every formula a `livecheck` block; `scripts/autobump.py` opens version bumps, and a
  reviewer updates the pins it leaves alone; see [Version bumps](docs/agent-context.md#version-bumps).
- Land formula changes through `publish.yml` (`brew pr-pull`), never a direct merge, so bottles
  ship with them; see [Bottles](docs/agent-context.md#bottles).
- Exercise both installer entrypoints against the real bundled payload in isolated homes.
- Never activate hooks or modify live agent configuration during tests.
- Keep review packets immutable; rerun affected tests and independent reviews after fixes.

See [integration tests](tests/README.md) and [maintenance context](docs/agent-context.md).
