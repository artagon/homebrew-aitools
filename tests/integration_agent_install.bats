#!/usr/bin/env bats
# Bats behavior and compatibility suite for Ripwire agent-skill installers
# (`Formula/ripwire.rb` wrapper and `scripts/install-agent-skills.sh`,
# `artagon-shell/shell-testing/v1`).
#
# Executes both entrypoints against the pinned Ripwire 0.6.10 payload across
# stock macOS Bash 3.2 (`BATS_BASH32`) and modern Bash 5+ (`BATS_MODERN_BASH`)
# in isolated `HOME`, `TMPDIR`, and allowlisted `PATH` environments.

load helpers/agent_install_helper

setup_file() {
  agent_setup_file_shared
}

setup() {
  if [[ "$BATS_TEST_DESCRIPTION" == *"(bash 3.2):"* ]] && [[ "${AGENT_HAS_BASH32:-0}" -ne 1 ]]; then
    skip "macOS Bash 3.2 interpreter is not installed on $(uname -s)"
  fi
}

# ── Formula wrapper under Bash 3.2 ───────────────────────────────────────────

@test "formula wrapper (bash 3.2): regression default fallback to shared root" {
  run case_agent_regression "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" default
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): regression custom AGY_SKILLS_DIR detection and install" {
  run case_agent_regression "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" custom_agy
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): regression shared .agents root does not register hooks" {
  run case_agent_regression "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" shared_hook
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): default target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" default 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): default target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" default 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --all detected targets (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" all 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --all detected targets (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" all 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --claude target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" claude 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --claude target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" claude 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --codex target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" codex 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --codex target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" codex 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --agy target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" agy 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --agy target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" agy 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --kimi target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" kimi 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --kimi target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" kimi 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --grok target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" grok 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --grok target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" grok 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --copilot target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" copilot 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --copilot target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" copilot 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --shared target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" shared 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --shared target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" shared 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --claude --hook (standard skills + idempotent settings.json)" {
  run case_agent_hook_install "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" claude 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --claude --hook (--contributor + idempotent settings.json)" {
  run case_agent_hook_install "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" claude 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --codex --hook (standard skills + idempotent hooks.json)" {
  run case_agent_hook_install "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" codex 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): --codex --hook (--contributor + idempotent hooks.json)" {
  run case_agent_hook_install "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32" codex 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 3.2): non-mutating --help, --list, and unknown-option exit 2" {
  run case_agent_cli_contract "$AGENT_FORMULA_ENTRY" "$AGENT_BASH32"
  [ "$status" -eq 0 ]
}

# ── Formula wrapper under Bash 5+ ────────────────────────────────────────────

@test "formula wrapper (bash 5+): regression default fallback to shared root" {
  run case_agent_regression "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" default
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): regression custom AGY_SKILLS_DIR detection and install" {
  run case_agent_regression "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" custom_agy
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): regression shared .agents root does not register hooks" {
  run case_agent_regression "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" shared_hook
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): default target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" default 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): default target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" default 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --all detected targets (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" all 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --all detected targets (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" all 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --claude target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" claude 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --claude target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" claude 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --codex target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" codex 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --codex target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" codex 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --agy target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" agy 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --agy target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" agy 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --kimi target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" kimi 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --kimi target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" kimi 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --grok target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" grok 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --grok target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" grok 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --copilot target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" copilot 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --copilot target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" copilot 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --shared target (standard skills)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" shared 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --shared target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" shared 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --claude --hook (standard skills + idempotent settings.json)" {
  run case_agent_hook_install "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" claude 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --claude --hook (--contributor + idempotent settings.json)" {
  run case_agent_hook_install "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" claude 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --codex --hook (standard skills + idempotent hooks.json)" {
  run case_agent_hook_install "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" codex 0
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): --codex --hook (--contributor + idempotent hooks.json)" {
  run case_agent_hook_install "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH" codex 1
  [ "$status" -eq 0 ]
}

@test "formula wrapper (bash 5+): non-mutating --help, --list, and unknown-option exit 2" {
  run case_agent_cli_contract "$AGENT_FORMULA_ENTRY" "$AGENT_MODERN_BASH"
  [ "$status" -eq 0 ]
}

# ── Standalone scripts/install-agent-skills.sh under Bash 3.2 ────────────────

@test "standalone installer (bash 3.2): regression default fallback to shared root" {
  run case_agent_regression "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" default
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): regression custom AGY_SKILLS_DIR detection and install" {
  run case_agent_regression "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" custom_agy
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): regression shared .agents root does not register hooks" {
  run case_agent_regression "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" shared_hook
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): default target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" default 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): default target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" default 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --all detected targets (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" all 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --all detected targets (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" all 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --claude target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" claude 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --claude target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" claude 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --codex target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" codex 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --codex target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" codex 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --agy target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" agy 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --agy target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" agy 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --kimi target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" kimi 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --kimi target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" kimi 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --grok target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" grok 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --grok target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" grok 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --copilot target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" copilot 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --copilot target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" copilot 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --shared target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" shared 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --shared target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" shared 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --claude --hook (standard skills + idempotent settings.json)" {
  run case_agent_hook_install "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" claude 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --claude --hook (--contributor + idempotent settings.json)" {
  run case_agent_hook_install "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" claude 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --codex --hook (standard skills + idempotent hooks.json)" {
  run case_agent_hook_install "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" codex 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): --codex --hook (--contributor + idempotent hooks.json)" {
  run case_agent_hook_install "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32" codex 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 3.2): non-mutating --help, --list, and unknown-option exit 2" {
  run case_agent_cli_contract "$AGENT_STANDALONE_ENTRY" "$AGENT_BASH32"
  [ "$status" -eq 0 ]
}

# ── Standalone scripts/install-agent-skills.sh under Bash 5+ ─────────────────

@test "standalone installer (bash 5+): regression default fallback to shared root" {
  run case_agent_regression "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" default
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): regression custom AGY_SKILLS_DIR detection and install" {
  run case_agent_regression "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" custom_agy
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): regression shared .agents root does not register hooks" {
  run case_agent_regression "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" shared_hook
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): default target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" default 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): default target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" default 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --all detected targets (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" all 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --all detected targets (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" all 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --claude target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" claude 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --claude target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" claude 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --codex target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" codex 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --codex target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" codex 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --agy target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" agy 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --agy target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" agy 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --kimi target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" kimi 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --kimi target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" kimi 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --grok target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" grok 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --grok target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" grok 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --copilot target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" copilot 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --copilot target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" copilot 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --shared target (standard skills)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" shared 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --shared target (--contributor + prune)" {
  run case_agent_install_matrix "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" shared 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --claude --hook (standard skills + idempotent settings.json)" {
  run case_agent_hook_install "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" claude 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --claude --hook (--contributor + idempotent settings.json)" {
  run case_agent_hook_install "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" claude 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --codex --hook (standard skills + idempotent hooks.json)" {
  run case_agent_hook_install "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" codex 0
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): --codex --hook (--contributor + idempotent hooks.json)" {
  run case_agent_hook_install "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH" codex 1
  [ "$status" -eq 0 ]
}

@test "standalone installer (bash 5+): non-mutating --help, --list, and unknown-option exit 2" {
  run case_agent_cli_contract "$AGENT_STANDALONE_ENTRY" "$AGENT_MODERN_BASH"
  [ "$status" -eq 0 ]
}
