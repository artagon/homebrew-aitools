# Maintenance context

The tap ships the pinned upstream tgrep binary. Ripwire and ast-grep-valhalla build
from source against `tree-sitter-java-valhalla`, a patched tree-sitter-java 0.23.5
that parses the JDK 28 Valhalla `javac` syntax; CI publishes bottles of all four
formulae for Apple Silicon macOS 26. Ripwire bundles its upstream skills.
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

## Version bumps

- `autobump.yml` runs `scripts/autobump.sh pr` daily. The Bash script reads
  `brew livecheck --tap artagon/aitools --newer-only --json`, rewrites each url
  that names the current version, recomputes the sha256 after it, drops any
  `revision`, and opens one pull request per formula on `bump/<formula>-<version>`.
- Pull requests opened with `GITHUB_TOKEN` start no `pull_request` run, so the
  script dispatches `tests.yml` on the bump branch with a `formulae` input: the
  bumped formula, plus `ast-grep-valhalla` and `ripwire` for a grammar bump.
- Every formula needs a `livecheck` block and a `url` with a following `sha256`
  that contains the version string. Test a rewrite offline with
  `scripts/autobump.sh rewrite FILE OLD NEW`.
- The script never updates the integration test pins. A Ripwire bump that changes
  the bundled installer or skill set fails `tests.yml` until a reviewer checks the
  payload and updates `tests/integration_agent_install.py`.

## Bottles

- `tests.yml` and `publish.yml` follow the `brew tap-new` templates and pin the
  same action SHAs. `tests.yml` runs `brew test-bot` on `macos-26` only; add a
  Linux entry once Ripwire's C++23 build is proven there, because a failed job
  blocks publishing.
- test-bot sets each bottle's `root_url` to
  `<tap remote>/releases/download/<formula>-<version>`, so `brew pr-pull` uploads
  to GitHub Releases. Do not pass `--root-url` or enable GitHub Packages.
- `brew pr-pull` reads bottle artifacts from the `tests.yml` check suite on the
  pull request's head commit, whatever event started it.
- Publish with `gh workflow run publish.yml -f pull_request=<number>`; GitHub
  dispatches only workflows that exist on the default branch. A formula pull
  request merged without it ships without bottles.
- Installs need the tap trusted (`brew trust`); every workflow trusts it first.

## Workflow security

- Pin every action to a full commit SHA with its tag in a comment, and verify
  that the tag resolves to that commit before changing a pin.
- Keep `permissions: {}` at the workflow level and grant each job only what it
  uses. `tests.yml` runs pull request code, including fork code, with a
  read-only token and no secrets.
- `publish.yml` gives `brew pr-pull` a write token and signs what it uploads.
  Before either, it requires: a run from `main` (git-try-push pushes the run's
  checkout to `main`); an open pull request from a branch of this repository
  that targets `main` (a fork's `tests.yml` run could upload arbitrary
  `bottles_*` artifacts); a head equal to the required `head_sha` that already
  contains current `main`; and a passing newest `tests.yml` run from this
  repository, because `brew pr-pull` checks only that the run completed. The
  push tries once, so a moved `main` fails instead of rebasing the bottles.
- `tests.yml` uploads bottles only from a passing run and restores no cache,
  because its artifacts become release assets.
- Do not pass `token:` to setup-homebrew: it writes the token into the global
  Git config for the rest of the job. The tap is public; git-try-push takes
  its own token. Scope secrets to the steps that use them.
- Jobs that hold write tokens set `stable: true`; otherwise setup-homebrew
  runs Homebrew's `main` branch in taps.
- Never use `pull_request_target` or `workflow_run`, and never expand `${{ }}`
  inputs inside `run:`; pass them through `env` and validate them.
- `autobump.yml` has no `actions/checkout`; pushes authenticate through
  `gh auth setup-git`, so no token is stored in `.git/config`.
  `scripts/autobump.sh` rejects unexpected formula names and upstream versions.
- Lint with `actionlint` and audit with `zizmor --persona=auditor` after every
  workflow change. When zizmor's online impostor-commit audit cannot reach
  GitHub, verify each pin with `gh api repos/<owner>/<repo>/git/ref/tags/<tag>`.
- Residual risks: `brew pr-upload` trusts the file paths in the bottle JSON of
  the artifact, which matters only once this repository's own runs are
  compromised; and `tests/integration_agent_install.py` pins Ripwire's
  installer but not its hook scripts.

Use [the integration suite](../tests/README.md) to validate wrapper behavior with
real payloads. An extracted Ruby-evaluated wrapper test does not prove Homebrew
installation, upgrade, permissions, or formula-test lifecycle behavior. Verify
those through actual Homebrew commands in an isolated prefix. Archive checksum
verification does not prove execution on another architecture or operating system.
