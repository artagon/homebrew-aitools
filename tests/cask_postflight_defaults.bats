#!/usr/bin/env bats
# Bats behavior and compatibility suite for artagon/aitools macOS cask
# `postflight_steps` defaults and `HOMEBREW_*` environment-flag overrides
# (`Casks/markdown-preview.rb`, `Casks/ghostty.rb`, `Casks/hammerspoon.rb`).
#
# Extracts the exact inline `postflight_steps` script from each cask and runs
# every scenario under stock macOS Bash 3.2 (`BATS_BASH32`) and modern Bash 5+
# (`BATS_MODERN_BASH`) against stubbed `defaults` and `duti` binaries in
# `$BATS_TEST_TMPDIR`, with zero writes to live macOS preferences or
# LaunchServices.

setup_file() {
  bats_require_minimum_version 1.5.0
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export REPO_ROOT

  CASK_BASH32="${BATS_BASH32:-/bin/bash}"
  CASK_HAS_BASH32=0
  if [[ -x "${CASK_BASH32}" ]] && "${CASK_BASH32}" -c '(( BASH_VERSINFO[0] == 3 ))' 2>/dev/null; then
    CASK_HAS_BASH32=1
  fi
  if [[ "$(uname -s)" == "Darwin" ]] && [[ "${CASK_HAS_BASH32}" -ne 1 ]]; then
    echo "macOS Bash 3.2 interpreter not found or invalid: ${CASK_BASH32}" >&2
    return 1
  fi
  export CASK_BASH32 CASK_HAS_BASH32

  CASK_MODERN_BASH="${BATS_MODERN_BASH:-}"
  if [[ -z "${CASK_MODERN_BASH}" ]]; then
    local candidate
    for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash)"; do
      if [[ -x "${candidate}" ]] && "${candidate}" -c '(( BASH_VERSINFO[0] >= 5 ))' 2>/dev/null; then
        CASK_MODERN_BASH="${candidate}"
        break
      fi
    done
  fi
  if [[ -z "${CASK_MODERN_BASH}" ]] || [[ ! -x "${CASK_MODERN_BASH}" ]] || ! "${CASK_MODERN_BASH}" -c '(( BASH_VERSINFO[0] >= 5 ))' 2>/dev/null; then
    echo "Modern Bash 5+ interpreter not found or invalid: ${CASK_MODERN_BASH:-unset} (set BATS_MODERN_BASH)" >&2
    return 1
  fi
  export CASK_MODERN_BASH

  command -v ruby >/dev/null 2>&1 || {
    echo "ruby is required to extract cask postflight_steps scripts" >&2
    return 1
  }
}

setup() {
  if [[ "${BATS_TEST_DESCRIPTION}" == *"(bash 3.2):"* ]] && [[ "${CASK_HAS_BASH32:-0}" -ne 1 ]]; then
    skip "macOS Bash 3.2 interpreter is not installed on $(uname -s)"
  fi

  TEST_HOME="${BATS_TEST_TMPDIR}/home"
  TEST_PREFIX="${BATS_TEST_TMPDIR}/prefix"
  TEST_BIN="${TEST_PREFIX}/bin"
  TEST_LOG="${BATS_TEST_TMPDIR}/calls.log"
  mkdir -p "${TEST_HOME}" "${TEST_BIN}"
  : >"${TEST_LOG}"

  FAKE_DEFAULTS="${TEST_BIN}/defaults"
  cat >"${FAKE_DEFAULTS}" <<'EOF'
#!/bin/sh
printf 'defaults' >>"${TEST_LOG}"
for arg in "$@"; do
  printf ' %s' "${arg}" >>"${TEST_LOG}"
done
printf '\n' >>"${TEST_LOG}"
if [ -n "${FAKE_DEFAULTS_FAIL_KEY:-}" ] && [ "${3:-}" = "${FAKE_DEFAULTS_FAIL_KEY}" ]; then
  exit 1
fi
EOF
  chmod 0755 "${FAKE_DEFAULTS}"

  FAKE_DUTI="${TEST_BIN}/duti"
  cat >"${FAKE_DUTI}" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-d" ]; then
  printf 'duti -d %s\n' "${2:-}" >>"${TEST_LOG}"
  status="${FAKE_DUTI_GET_STATUS:-0}"
  if [ "${status}" -eq 0 ]; then
    printf '%s\n' "${FAKE_DUTI_CURRENT-com.microsoft.VSCode}"
  fi
  exit "${status}"
fi
printf 'duti' >>"${TEST_LOG}"
for arg in "$@"; do
  printf ' %s' "${arg}" >>"${TEST_LOG}"
done
printf '\n' >>"${TEST_LOG}"
exit "${FAKE_DUTI_SET_STATUS:-0}"
EOF
  chmod 0755 "${FAKE_DUTI}"
}

extract_cask_script() {
  local cask_name="$1"
  local out_file="$2"
  ruby - "${REPO_ROOT}/Casks/${cask_name}.rb" "${out_file}" "${FAKE_DEFAULTS}" "${BATS_TEST_TMPDIR}/missing" <<'RUBY'
require "shellwords"

cask_path, out_path, fake_defaults, missing_prefix = ARGV
source = File.read(cask_path)
unless source.include?('"-euo", "pipefail", "-c"') && source.include?("must_succeed:   false")
  abort("Missing expected postflight_steps invocation options in #{cask_path}")
end

match = source.match(/postflight_steps\s+do.*?<<~'SH',\n(.*?)\n\s*SH\n/m)
abort("Could not extract postflight_steps script from #{cask_path}") unless match

lines = match[1].lines
indent = lines.reject { |line| line.strip.empty? }.map { |line| line[/\A */].length }.min || 0
script = lines.map { |line| line.sub(/\A {0,#{indent}}/, "") }.join
script = script.gsub("/usr/bin/defaults") { Shellwords.escape(fake_defaults) }
script = script.gsub("/opt/homebrew/bin/duti") { "#{missing_prefix}/opt-duti" }
script = script.gsub("/usr/local/bin/duti") { "#{missing_prefix}/local-duti" }
File.write(out_path, script)
RUBY
}

run_cask_postflight() {
  local cask_name="$1"
  local bash_bin="$2"
  local prefix_arg="${TEST_PREFIX}"
  shift 2

  if [[ "${1:-}" == "--prefix="* ]]; then
    prefix_arg="${1#--prefix=}"
    shift
  fi

  local script_file="${BATS_TEST_TMPDIR}/${cask_name}.sh"
  extract_cask_script "${cask_name}" "${script_file}"
  : >"${TEST_LOG}"

  env -i \
    PATH="/usr/bin:/bin" \
    HOME="${TEST_HOME}" \
    TMPDIR="${BATS_TEST_TMPDIR}" \
    TEST_LOG="${TEST_LOG}" \
    ${@+"$@"} \
    "${bash_bin}" -euo pipefail "${script_file}" "${prefix_arg}"
}

case_markdown_preview_defaults() {
  local bash_bin="$1"
  run run_cask_postflight markdown-preview "${bash_bin}" FAKE_DUTI_CURRENT=com.microsoft.VSCode
  [ "${status}" -eq 0 ]

  local expected
  expected="$(
    cat <<'EOF'
defaults write doc.md-preview SUEnableAutomaticChecks -bool false
defaults write doc.md-preview SUAutomaticallyUpdate -bool false
defaults write doc.md-preview SUSendProfileInfo -bool false
defaults write doc.md-preview SUHasLaunchedBefore -bool true
defaults write doc.md-preview MarkdownPreview.shareAnonymousUsageAnalytics -bool false
defaults write doc.md-preview MarkdownPreview.sendAnonymousCrashReports -bool false
duti -d net.daringfireball.markdown
duti -s doc.md-preview net.daringfireball.markdown all
EOF
  )"
  [ "$(cat "${TEST_LOG}")" = "${expected}" ]
}

case_markdown_preview_duti_and_ci() {
  local bash_bin="$1"

  # Idempotent when duti -d already returns doc.md-preview (including trailing whitespace/CR).
  run run_cask_postflight markdown-preview "${bash_bin}" "FAKE_DUTI_CURRENT=  doc.md-preview  "
  [ "${status}" -eq 0 ]
  run -1 grep -q '^duti -s ' "${TEST_LOG}"
  grep -q '^duti -d net.daringfireball.markdown$' "${TEST_LOG}"

  # CI=true skips duti; falsy CI values (0, false, blank) do NOT skip duti.
  run run_cask_postflight markdown-preview "${bash_bin}" CI=true FAKE_DUTI_CURRENT=com.microsoft.VSCode
  [ "${status}" -eq 0 ]
  run -1 grep -q '^duti ' "${TEST_LOG}"

  run run_cask_postflight markdown-preview "${bash_bin}" CI=0 FAKE_DUTI_CURRENT=com.microsoft.VSCode
  [ "${status}" -eq 0 ]
  grep -q '^duti -s doc.md-preview net.daringfireball.markdown all$' "${TEST_LOG}"

  run run_cask_postflight markdown-preview "${bash_bin}" "CI=   " FAKE_DUTI_CURRENT=com.microsoft.VSCode
  [ "${status}" -eq 0 ]
  grep -q '^duti -s doc.md-preview net.daringfireball.markdown all$' "${TEST_LOG}"

  # Explicit per-cask override wins over CI=true.
  run run_cask_postflight markdown-preview "${bash_bin}" CI=true HOMEBREW_MARKDOWN_PREVIEW_SET_DEFAULT=1 FAKE_DUTI_CURRENT=com.microsoft.VSCode
  [ "${status}" -eq 0 ]
  grep -q '^duti -s doc.md-preview net.daringfireball.markdown all$' "${TEST_LOG}"
}

case_markdown_preview_flags_and_fail_closed() {
  local bash_bin="$1"

  # Per-cask overrides tap-wide; whitespace-only per-cask falls back to tap-wide.
  run run_cask_postflight markdown-preview "${bash_bin}" \
    HOMEBREW_AITOOLS_AUTO_UPDATES=1 \
    "HOMEBREW_MARKDOWN_PREVIEW_AUTO_UPDATES=  FALSE  " \
    HOMEBREW_AITOOLS_TELEMETRY=YES \
    "HOMEBREW_MARKDOWN_PREVIEW_TELEMETRY=   " \
    HOMEBREW_MARKDOWN_PREVIEW_SET_DEFAULT=off
  [ "${status}" -eq 0 ]

  local expected
  expected="$(
    cat <<'EOF'
defaults write doc.md-preview SUEnableAutomaticChecks -bool false
defaults write doc.md-preview SUAutomaticallyUpdate -bool false
defaults write doc.md-preview SUSendProfileInfo -bool false
defaults write doc.md-preview SUHasLaunchedBefore -bool true
defaults write doc.md-preview MarkdownPreview.shareAnonymousUsageAnalytics -bool true
defaults write doc.md-preview MarkdownPreview.sendAnonymousCrashReports -bool true
EOF
  )"
  [ "$(cat "${TEST_LOG}")" = "${expected}" ]

  # Invalid boolean values fail closed (false) with a stderr warning, including SET_DEFAULT.
  run run_cask_postflight markdown-preview "${bash_bin}" \
    HOMEBREW_MARKDOWN_PREVIEW_SKIP_DEFAULTS=disabled \
    HOMEBREW_MARKDOWN_PREVIEW_AUTO_UPDATES=flase \
    HOMEBREW_MARKDOWN_PREVIEW_TELEMETRY=nope \
    HOMEBREW_MARKDOWN_PREVIEW_SET_DEFAULT=flase
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"ignoring invalid boolean flag value"* ]]
  grep -q '^defaults write doc.md-preview SUEnableAutomaticChecks -bool false$' "${TEST_LOG}"
  grep -q '^defaults write doc.md-preview MarkdownPreview.shareAnonymousUsageAnalytics -bool false$' "${TEST_LOG}"
  run -1 grep -q '^duti ' "${TEST_LOG}"

  # SKIP_DEFAULTS=1 performs zero writes; per-cask SKIP_DEFAULTS=0 overrides tap-wide SKIP_DEFAULTS=1.
  run run_cask_postflight markdown-preview "${bash_bin}" HOMEBREW_AITOOLS_SKIP_DEFAULTS=1
  [ "${status}" -eq 0 ]
  [ ! -s "${TEST_LOG}" ]

  run run_cask_postflight markdown-preview "${bash_bin}" \
    HOMEBREW_AITOOLS_SKIP_DEFAULTS=1 \
    HOMEBREW_MARKDOWN_PREVIEW_SKIP_DEFAULTS=0 \
    HOMEBREW_MARKDOWN_PREVIEW_SET_DEFAULT=0
  [ "${status}" -eq 0 ]
  grep -q '^defaults write doc.md-preview SUEnableAutomaticChecks -bool false$' "${TEST_LOG}"
}

case_markdown_preview_failure_paths() {
  local bash_bin="$1"

  # A failing defaults write does not abort remaining writes, and propagates non-zero exit.
  run run_cask_postflight markdown-preview "${bash_bin}" \
    FAKE_DEFAULTS_FAIL_KEY=SUEnableAutomaticChecks \
    HOMEBREW_MARKDOWN_PREVIEW_SET_DEFAULT=0
  [ "${status}" -eq 1 ]
  grep -q '^defaults write doc.md-preview SUAutomaticallyUpdate -bool false$' "${TEST_LOG}"
  grep -q '^defaults write doc.md-preview MarkdownPreview.sendAnonymousCrashReports -bool false$' "${TEST_LOG}"

  # duti -d exit 1 (no handler set) proceeds to duti -s.
  run run_cask_postflight markdown-preview "${bash_bin}" FAKE_DUTI_GET_STATUS=1
  [ "${status}" -eq 0 ]
  grep -q '^duti -s doc.md-preview net.daringfireball.markdown all$' "${TEST_LOG}"

  # duti -d exit 2 (error) skips duti -s and exits non-zero.
  run run_cask_postflight markdown-preview "${bash_bin}" FAKE_DUTI_GET_STATUS=2
  [ "${status}" -eq 1 ]
  run -1 grep -q '^duti -s ' "${TEST_LOG}"

  # duti -s failure propagates non-zero exit with warning.
  run run_cask_postflight markdown-preview "${bash_bin}" FAKE_DUTI_CURRENT=com.microsoft.VSCode FAKE_DUTI_SET_STATUS=1
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"duti failed"* ]]

  # Missing duti emits warning and exits non-zero without blocking defaults writes.
  run run_cask_postflight markdown-preview "${bash_bin}" "--prefix=${BATS_TEST_TMPDIR}/no-duti"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"duti not found"* ]]
  grep -q '^defaults write doc.md-preview MarkdownPreview.sendAnonymousCrashReports -bool false$' "${TEST_LOG}"
}

case_sparkle_cask() {
  local cask_name="$1"
  local bundle_id="$2"
  local env_prefix="$3"
  local bash_bin="$4"

  if [[ ! -f "${REPO_ROOT}/Casks/${cask_name}.rb" ]]; then
    skip "Casks/${cask_name}.rb is not present in this checkout"
  fi

  run run_cask_postflight "${cask_name}" "${bash_bin}"
  [ "${status}" -eq 0 ]

  local expected
  expected="$(
    cat <<EOF
defaults write ${bundle_id} SUEnableAutomaticChecks -bool false
defaults write ${bundle_id} SUAutomaticallyUpdate -bool false
defaults write ${bundle_id} SUSendProfileInfo -bool false
defaults write ${bundle_id} SUHasLaunchedBefore -bool true
EOF
  )"
  [ "$(cat "${TEST_LOG}")" = "${expected}" ]

  run run_cask_postflight "${cask_name}" "${bash_bin}" "${env_prefix}_AUTO_UPDATES=on"
  [ "${status}" -eq 0 ]
  [ "$(cat "${TEST_LOG}")" = "defaults write ${bundle_id} SUEnableAutomaticChecks -bool true" ]

  run run_cask_postflight "${cask_name}" "${bash_bin}" \
    HOMEBREW_AITOOLS_SKIP_DEFAULTS=1 \
    "${env_prefix}_SKIP_DEFAULTS=0" \
    HOMEBREW_AITOOLS_AUTO_UPDATES=yes
  [ "${status}" -eq 0 ]
  [ "$(cat "${TEST_LOG}")" = "defaults write ${bundle_id} SUEnableAutomaticChecks -bool true" ]

  # Invalid AUTO_UPDATES value fails closed to false.
  run run_cask_postflight "${cask_name}" "${bash_bin}" "${env_prefix}_AUTO_UPDATES=invalid"
  [ "${status}" -eq 0 ]
  [ "$(cat "${TEST_LOG}")" = "${expected}" ]

  # Failing first defaults write still writes remaining keys and exits non-zero.
  run run_cask_postflight "${cask_name}" "${bash_bin}" FAKE_DEFAULTS_FAIL_KEY=SUEnableAutomaticChecks
  [ "${status}" -eq 1 ]
  grep -q "^defaults write ${bundle_id} SUHasLaunchedBefore -bool true\$" "${TEST_LOG}"

  run run_cask_postflight "${cask_name}" "${bash_bin}" "${env_prefix}_SKIP_DEFAULTS=true"
  [ "${status}" -eq 0 ]
  [ ! -s "${TEST_LOG}" ]
}

@test "markdown-preview (bash 3.2): default settings disable updates and telemetry and set duti once" {
  case_markdown_preview_defaults "${CASK_BASH32}"
}

@test "markdown-preview (bash 5+): default settings disable updates and telemetry and set duti once" {
  case_markdown_preview_defaults "${CASK_MODERN_BASH}"
}

@test "markdown-preview (bash 3.2): duti idempotency and CI gating" {
  case_markdown_preview_duti_and_ci "${CASK_BASH32}"
}

@test "markdown-preview (bash 5+): duti idempotency and CI gating" {
  case_markdown_preview_duti_and_ci "${CASK_MODERN_BASH}"
}

@test "markdown-preview (bash 3.2): flag precedence, whitespace fallback, and fail-closed validation" {
  case_markdown_preview_flags_and_fail_closed "${CASK_BASH32}"
}

@test "markdown-preview (bash 5+): flag precedence, whitespace fallback, and fail-closed validation" {
  case_markdown_preview_flags_and_fail_closed "${CASK_MODERN_BASH}"
}

@test "markdown-preview (bash 3.2): failure propagation for defaults and duti" {
  case_markdown_preview_failure_paths "${CASK_BASH32}"
}

@test "markdown-preview (bash 5+): failure propagation for defaults and duti" {
  case_markdown_preview_failure_paths "${CASK_MODERN_BASH}"
}

@test "ghostty (bash 3.2): Sparkle defaults, env precedence, fail-closed, and failure propagation" {
  case_sparkle_cask ghostty com.mitchellh.ghostty HOMEBREW_GHOSTTY "${CASK_BASH32}"
}

@test "ghostty (bash 5+): Sparkle defaults, env precedence, fail-closed, and failure propagation" {
  case_sparkle_cask ghostty com.mitchellh.ghostty HOMEBREW_GHOSTTY "${CASK_MODERN_BASH}"
}

@test "hammerspoon (bash 3.2): Sparkle defaults, env precedence, fail-closed, and failure propagation" {
  case_sparkle_cask hammerspoon org.hammerspoon.Hammerspoon HOMEBREW_HAMMERSPOON "${CASK_BASH32}"
}

@test "hammerspoon (bash 5+): Sparkle defaults, env precedence, fail-closed, and failure propagation" {
  case_sparkle_cask hammerspoon org.hammerspoon.Hammerspoon HOMEBREW_HAMMERSPOON "${CASK_MODERN_BASH}"
}
