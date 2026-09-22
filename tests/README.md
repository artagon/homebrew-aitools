# Agent installer integration tests

Run from the repository root:

```sh
rtk python3 tests/integration_agent_install.py --receipt /tmp/ripwire-integration.json
```

The suite requires Python 3.9+, Ruby, jq, macOS Bash 3.2, a modern Bash 5+, and the
installed Ripwire 0.5.0 payload. Paths can be supplied with `--pkgshare`,
`--bash32`, and `--modern-bash`. Missing prerequisites fail the run; no cases skip.
`--regressions-only` runs the twelve cases covering the original installer defects.

Both entrypoints run: the standalone script and the exact formula wrapper heredoc
evaluated by Ruby, preserving Ruby interpolation and shell escaping. Every run
checks the bundled installer's SHA-256 against the pinned 0.5.0 installer. Tests
copy the real payload into temporary storage, so upstream hook chmod calls cannot
touch the installed files. The installer is not mocked. This validates wrapper
behavior, not Homebrew's complete installation or upgrade transaction.

Each case has its own temporary HOME, an environment built from scratch, and a
PATH containing only required utilities plus the selected Bash. No installed
agent executable or live agent configuration participates. Explicit hook cases
register real Claude/Codex hooks in temporary JSON files; they never execute hooks.

Coverage includes default detection/fallback, all detected clients, all seven
explicit destinations, contributor inclusion/removal, manifest and symlink
contents, repeat installation, custom Antigravity detection and listing, shared
roots without Codex, explicit Claude/Codex hook registration and idempotence,
preservation of unrelated settings, and nonmutating help/list/invalid options.
Both shells run every case. Failures return nonzero and the JSON receipt records
the tested source hashes and per-case results. Temporary evidence is retained at
the receipt's `scratch` path for inspection; it contains no live user state.
