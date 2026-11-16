#!/usr/bin/env bash
# Generate SPDX 2.3 + CycloneDX 1.6 SBOMs and build-manifest.json for bottles
# built by `brew test-bot` in `.github/workflows/tests.yml`.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland; requires brew, jq, syft.
# Inputs (via environment, never shell-interpolated in YAML):
#   MATRIX_OS, PR_HEAD_SHA, GITHUB_SHA, GITHUB_EVENT_NAME, GITHUB_REF,
#   GITHUB_RUN_ID, GITHUB_RUN_ATTEMPT, RUNNER_OS, RUNNER_ARCH, RUNNER_TEMP.
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/ci/common.sh
source "${CI_DIR}/common.sh"

[[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
ci::require_sha40 "${PR_HEAD_SHA:-}" "PR_HEAD_SHA"
ci::require_sha40 "${GITHUB_SHA:-}" "GITHUB_SHA"
ci::require_uint "${GITHUB_RUN_ID:-}" "GITHUB_RUN_ID"
ci::require_uint "${GITHUB_RUN_ATTEMPT:-}" "GITHUB_RUN_ATTEMPT"
[[ "${MATRIX_OS:-}" =~ ^[A-Za-z0-9._-]+$ ]] || ci::fail "Invalid MATRIX_OS: ${MATRIX_OS:-}"

prov_dir="${RUNNER_TEMP}/provenance"
rm -rf -- "${prov_dir}"
mkdir -p -- "${prov_dir}"
entries_jsonl="${prov_dir}/entries.jsonl"
: >"${entries_jsonl}"
: >"${prov_dir}/SHA256SUMS"

shopt -s nullglob
json_files=(./*.bottle.json)
shopt -u nullglob

for json_file in ${json_files[@]+"${json_files[@]}"}
do
  base_json="$(basename "${json_file}")"
  ci::require_safe_filename "${base_json}" "bottle JSON filename"
  formula_name="$(jq -r 'to_entries[0].value.formula.name' "${json_file}")"
  pkg_version="$(jq -r 'to_entries[0].value.formula.pkg_version' "${json_file}")"
  root_url="$(jq -r 'to_entries[0].value.bottle.root_url' "${json_file}")"
  rebuild="$(jq -r 'to_entries[0].value.bottle.rebuild' "${json_file}")"

  ci::require_formula_name "${formula_name}" "formula.name"
  ci::require_uint "${rebuild}" "bottle.rebuild"
  bottle_json_sha256="$(ci::sha256_hex "${json_file}")"

  while IFS=$'\t' read -r tag release_filename brew_filename expected_sha256
  do
    ci::require_safe_filename "${release_filename}" "release_filename"
    ci::require_safe_filename "${brew_filename}" "brew_filename"
    ci::require_sha256 "${expected_sha256}" "bottle.tags.${tag}.sha256"

    [[ -f "./${brew_filename}" ]] ||
      ci::fail "Missing bottle tarball ${brew_filename} referenced by ${base_json}"
    actual_sha256="$(ci::sha256_hex "./${brew_filename}")"
    [[ "${actual_sha256}" = "${expected_sha256}" ]] ||
      ci::fail "Digest mismatch for ${brew_filename}: expected ${expected_sha256}, got ${actual_sha256}"

    spdx_path="${prov_dir}/${release_filename}.spdx.json"
    cdx_path="${prov_dir}/${release_filename}.cdx.json"
    syft scan "file:./${brew_filename}" \
      --source-name "${formula_name}" \
      --source-version "${pkg_version}" \
      --select-catalogers "+javascript-package-cataloger" \
      -o "spdx-json=${spdx_path}" \
      -o "cyclonedx-json=${cdx_path}"

    spdx_sha256="$(ci::sha256_hex "${spdx_path}")"
    cdx_sha256="$(ci::sha256_hex "${cdx_path}")"

    printf '%s  %s\n' "${actual_sha256}" "${brew_filename}" >>"${prov_dir}/SHA256SUMS"
    printf '%s  %s\n' "${actual_sha256}" "${release_filename}" >>"${prov_dir}/SHA256SUMS"

    jq -c -n \
      --arg formula "${formula_name}" \
      --arg pkg_version "${pkg_version}" \
      --arg root_url "${root_url}" \
      --argjson rebuild "${rebuild}" \
      --arg tag "${tag}" \
      --arg brew_filename "${brew_filename}" \
      --arg release_filename "${release_filename}" \
      --arg bottle_sha256 "${actual_sha256}" \
      --arg bottle_json_filename "${base_json}" \
      --arg bottle_json_sha256 "${bottle_json_sha256}" \
      --arg spdx_sha256 "${spdx_sha256}" \
      --arg cdx_sha256 "${cdx_sha256}" \
      '{
        formula: $formula,
        pkg_version: $pkg_version,
        root_url: $root_url,
        rebuild: $rebuild,
        tag: $tag,
        brew_filename: $brew_filename,
        release_filename: $release_filename,
        bottle_sha256: $bottle_sha256,
        bottle_json_filename: $bottle_json_filename,
        bottle_json_sha256: $bottle_json_sha256,
        spdx_sha256: $spdx_sha256,
        cdx_sha256: $cdx_sha256
      }' >>"${entries_jsonl}"
  done < <(
    jq -r '
      to_entries[0].value.bottle.tags
      | to_entries[]
      | [.key, .value.filename, .value.local_filename, .value.sha256]
      | @tsv
    ' "${json_file}"
  )
done

brew_ver="$(brew --version | head -n 1)"
jq -s \
  --arg head_sha "${PR_HEAD_SHA}" \
  --arg checkout_sha "${GITHUB_SHA}" \
  --arg event_name "${GITHUB_EVENT_NAME:-}" \
  --arg ref "${GITHUB_REF:-}" \
  --arg run_id "${GITHUB_RUN_ID}" \
  --arg run_attempt "${GITHUB_RUN_ATTEMPT}" \
  --arg matrix_os "${MATRIX_OS}" \
  --arg runner_os "${RUNNER_OS:-}" \
  --arg runner_arch "${RUNNER_ARCH:-}" \
  --arg homebrew_version "${brew_ver}" \
  '{
    schema: "artagon-bottle-build-manifest/v1",
    head_sha: $head_sha,
    checkout_sha: $checkout_sha,
    event_name: $event_name,
    ref: $ref,
    run_id: $run_id,
    run_attempt: $run_attempt,
    matrix_os: $matrix_os,
    runner_os: $runner_os,
    runner_arch: $runner_arch,
    homebrew_version: $homebrew_version,
    bottles: .
  }' "${entries_jsonl}" >"${prov_dir}/build-manifest.json"
rm -f -- "${entries_jsonl}"
