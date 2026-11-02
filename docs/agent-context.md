# Maintenance context

The tap ships the pinned upstream tgrep binary. Ripwire and ast-grep-valhalla build
from source against `tree-sitter-java-valhalla`, a patched tree-sitter-java 0.23.5
that parses the JDK 28 Valhalla `javac` syntax. Ripwire bundles its upstream skills.
Homebrew install and upgrade must not activate agent integrations. Activation is
explicit through the formula-generated `ripwire-agent-install` or
`scripts/install-agent-skills.sh`.

Both entrypoints support stock macOS Bash 3.2. Keep invocation arrays nonempty:
expanding an empty array under `set -u` aborts Bash 3.2. The installer path is the
first element of the argument array; optional flags are appended to it.

Codex detection uses its executable or its own configuration root. The shared
`.agents` root is a fallback destination and does not establish Codex presence.
Antigravity detection also recognizes an existing `AGY_SKILLS_DIR` directory.

The README qualifies formula names because Homebrew core also contains `tgrep` and
`ast-grep`. ast-grep-valhalla declares `conflicts_with "ast-grep"` because both
install the `ast-grep` and `sg` binaries.

## Java grammar patch

- The patch is the `__END__` section of `Formula/tree-sitter-java-valhalla.rb`. It
  edits `grammar.js` and adds `test/corpus/valhalla.txt`. `install` regenerates
  `src/` at ABI 14 with the CLI's built-in QuickJS runtime, so Node is not needed.
- Derive new syntax from the target JDK's javac parser
  (`lib/src.zip`: `jdk.compiler/com/sun/tools/javac/parser/JavacParser.java`).
  Compile each new corpus case with that JDK and `--enable-preview` first.
- Keep the patch additive. Parse a large Java corpus with the old and new grammar;
  every file that the old grammar parses without errors must keep a byte-identical
  tree, ranges included. Run `tree-sitter test` over both corpora.
- When the patch changes, bump the `revision` of `tree-sitter-java-valhalla`,
  `ast-grep-valhalla`, and `ripwire`. The last two compile the grammar in and do
  not rebuild otherwise.
- ast-grep-valhalla swaps in the grammar crate through Cargo `[patch.crates-io]`,
  so the crate version must equal the version that ast-grep pins. Ripwire copies
  `src/parser.c` and `src/tree_sitter/*.h` over its vendored copy and patches
  `queries/java/tags.scm`. Recheck both pins when bumping either upstream.

Use [the integration suite](../tests/README.md) to validate wrapper behavior with
real payloads. An extracted Ruby-evaluated wrapper test does not prove Homebrew
installation, upgrade, permissions, or formula-test lifecycle behavior. Verify
those through actual Homebrew commands in an isolated prefix. Archive checksum
verification does not prove execution on another architecture or operating system.
