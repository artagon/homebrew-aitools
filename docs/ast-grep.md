# Repository ast-grep checks

The tap uses Ruby formulae, Bash maintenance scripts, Bats tests, and GitHub
Actions YAML workflows. Upstream Rust, Java, JavaScript, Go, and Python code is
downloaded during formula builds; it is not a source tree in this repository.

[`sgconfig.yml`](../sgconfig.yml) loads rules from `rules/` and tests from
`rule-tests/`. Ruby, Bash `*.sh`, and YAML have built-in language mappings, and
the additional Bash basename globs cover `*.bash` helpers and `*.bats` suites.
No custom grammar library is needed for these checks.

## Run the checks

From the repository root, with `ast-grep` on `PATH` (pass `.github/workflows`
explicitly so hidden workflow files are included alongside `.`):

```sh
ast-grep test --config sgconfig.yml
ast-grep scan --config sgconfig.yml --inspect summary . .github/workflows
```

If `ast-grep` is not installed, the tap provides it:

```sh
brew install artagon/aitools/ast-grep-valhalla
```

An existing Homebrew core `ast-grep` also supports the Ruby, Bash, and YAML
rules. The two formulae install conflicting executables; only one can be linked.

All configured rules have `error` severity, so findings make `scan` exit nonzero.

## Rule coverage

| Rule | Language & Files | Check |
| --- | --- | --- |
| `formula-livecheck` | Ruby (`Formula/*.rb`) | A class directly inheriting from `Formula` declares a `livecheck do` block directly in its body. Blocks inside methods or resources do not count. |
| `formula-no-interpolated-url` | Ruby (`Formula/*.rb`) | Source and resource `url` arguments contain no Ruby interpolation (`#{...}`). `url :stable` remains valid. |
| `formula-source-sha256` | Ruby (`Formula/*.rb`) | A source `sha256` argument is a double-quoted literal containing 64 lowercase hexadecimal characters, as required by `autobump.sh`. Bottle blocks are excluded. |
| `formula-cannot-represent-license` | Ruby (`Formula/*.rb`) | Any `Formula` class declaring `license :cannot_represent` installs `"LICENSE"` via `prefix.install` inside `def install`. |
| `formula-conflicts-same-name` | Ruby (`Formula/*.rb`) | Forbids declaring `conflicts_with` on configured same-named formulae across taps. |
| `bash-no-mapfile-readarray` | Bash (`scripts/**/*.sh`, `tests/helpers/**/*.bash`, `tests/**/*.bats`) | Rejects `mapfile` and `readarray` (with or without arguments, and with `builtin`/`command` prefixes), which macOS `/bin/bash` 3.2 lacks. |
| `bash-no-bash4-features` | Bash (`scripts/**/*.sh`, `tests/helpers/**/*.bash`, `tests/**/*.bats`) | Rejects Bash 4+ `declare`/`local`/`typeset` flags (`-A`, `-n`, `-g`, `-l`, `-u`, `-c`) incompatible with `/bin/bash` 3.2. |
| `workflow-no-dangerous-triggers` | YAML (`.github/workflows/*.yml`) | Rejects `pull_request_target` and `workflow_run` workflow triggers. |
| `workflow-pinned-uses-sha` | YAML (`.github/workflows/*.yml`) | Requires every external `uses:` reference to pin a full 40-character lowercase commit SHA (allowing `./.github/workflows/...` local reusable workflows). |
| `workflow-no-run-interpolation` | YAML (`.github/workflows/*.yml`) | Rejects direct `${{ ... }}` expression interpolation inside `run:` blocks so inputs pass via `env:` instead. |

Each rule has valid examples, invalid examples, and reviewed diagnostic
snapshots under `rule-tests/__snapshots__/`. Rules do not supply automatic fixes.

## Structural searches

Use an explicit language for one-off searches:

```sh
ast-grep run --lang ruby --pattern 'url $URL' Formula
ast-grep run --lang bash --pattern 'source $FILE' scripts tests/helpers
ast-grep run --lang yaml --pattern 'uses: $ACTION' .github/workflows
```

Inspect which rules apply to specific files:

```sh
ast-grep scan --config sgconfig.yml --inspect entity .github/workflows/publish.yml tests/verify_provenance.bats
```

Rule `files` globs are relative to the project root, while `languageGlobs`
entries match basenames.

## Limits and maintenance

These checks enforce structural invariants, not the full tap contract:

- They do not prove that a URL resolves, a checksum matches an archive, or a
  `livecheck` strategy succeeds online.
- They do not enforce that `sha256` appears on line `NR + 1` immediately after
  `url` without a trailing comment (`scripts/autobump.sh` layout contract).
- Bash inside Ruby heredocs (`Formula/*.rb` `<<~SH`) and YAML `run:` script
  bodies is not parsed as Bash AST. Continue running `brew style`, `brew audit`,
  `actionlint`, `zizmor`, and the isolated [installer and provenance tests](../tests/README.md).

When changing or adding a rule:

1. Add valid and invalid examples (including near misses) to `rule-tests/<id>-test.yml`.
2. Run `ast-grep test --config sgconfig.yml --filter '^RULE_ID$'` and review
   diagnostic ranges.
3. Accept intended snapshots with `--update-all`.
4. Run the full rule test suite and `ast-grep scan --config sgconfig.yml . .github/workflows`.
