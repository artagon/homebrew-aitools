#!/usr/bin/env bash
# Merge per-shard bottle and provenance artifacts for one matrix OS into the
# exact flat `bottles_${MATRIX_OS}` and `provenance_${MATRIX_OS}` layout
# expected by `publish.yml` and `sign-bottles.yml`.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland;
# requires awk, cp, grep, jq, mktemp, sort.
# Inputs (via environment, never shell-interpolated in YAML):
#   SHARDS_DIR, OUT_DIR, MATRIX_OS, HEAD_SHA, RUN_ID, RUN_ATTEMPT,
#   optional EXPECTED_SHARD_COUNT.
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/ci/common.sh
source "${CI_DIR}/common.sh"

readonly PKG_VERSION_RE='^[0-9A-Za-z._+-]+$'

work_dir=""
# Invoked indirectly via `trap cleanup EXIT`.
# shellcheck disable=SC2329
cleanup() {
  local rc=$?
  if [[ -n "${work_dir}" && -d "${work_dir}" ]]
  then
    rm -rf -- "${work_dir}" || true
  fi
  return "${rc}"
}
trap cleanup EXIT

file_has_line() {
  local needle="$1"
  local haystack="$2"
  [[ -s "${haystack}" ]] || return 1
  grep -Fxq -- "${needle}" "${haystack}"
}

main() {
  local shards_dir="${SHARDS_DIR:-}"
  local out_dir="${OUT_DIR:-}"
  local matrix_os="${MATRIX_OS:-}"
  local head_sha="${HEAD_SHA:-}"
  local run_id="${RUN_ID:-}"
  local run_attempt="${RUN_ATTEMPT:-}"
  local expected_shard_count="${EXPECTED_SHARD_COUNT:-}"

  [[ -n "${shards_dir}" && -d "${shards_dir}" ]] || ci::fail "SHARDS_DIR is not a directory: ${shards_dir:-<unset>}"
  [[ -n "${out_dir}" ]] || ci::fail "OUT_DIR must be set"
  ci::require_matrix_os "${matrix_os}" "MATRIX_OS"
  ci::require_sha40 "${head_sha}" "HEAD_SHA"
  ci::require_uint "${run_id}" "RUN_ID"
  ci::require_uint "${run_attempt}" "RUN_ATTEMPT"
  [[ "${run_attempt}" -ge 1 ]] || ci::fail "RUN_ATTEMPT must be >= 1 (got: ${run_attempt})"
  if [[ -n "${expected_shard_count}" ]]
  then
    ci::require_uint "${expected_shard_count}" "EXPECTED_SHARD_COUNT"
    [[ "${expected_shard_count}" -ge 1 ]] ||
      ci::fail "EXPECTED_SHARD_COUNT must be >= 1 (got: ${expected_shard_count})"
  fi

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/merge-shards.XXXXXX")"
  local stage_bottles="${work_dir}/bottles"
  local stage_prov="${work_dir}/provenance"
  local entries_jsonl="${work_dir}/entries.jsonl"
  local sorted_entries_json="${work_dir}/sorted-bottles.json"
  local seen_formula_tags="${work_dir}/seen-formula-tags.txt"
  local seen_brew_files="${work_dir}/seen-brew-files.txt"
  local seen_release_files="${work_dir}/seen-release-files.txt"
  local seen_json_files="${work_dir}/seen-json-files.txt"
  local shard_list_raw="${work_dir}/shards-raw.txt"
  local shard_list="${work_dir}/shards.txt"

  mkdir -p -- "${stage_bottles}" "${stage_prov}"
  : >"${entries_jsonl}"
  : >"${seen_formula_tags}"
  : >"${seen_brew_files}"
  : >"${seen_release_files}"
  : >"${seen_json_files}"
  : >"${shard_list_raw}"

  local -a shard_entries=()
  local entry_path=""
  shopt -s nullglob
  shard_entries=("${shards_dir}"/*)
  shopt -u nullglob
  for entry_path in ${shard_entries[@]+"${shard_entries[@]}"}
  do
    [[ -d "${entry_path}" ]] || ci::fail "Unexpected non-directory entry in SHARDS_DIR: ${entry_path}"
    printf '%s\n' "${entry_path}" >>"${shard_list_raw}"
  done
  LC_ALL=C sort "${shard_list_raw}" >"${shard_list}"

  local shard_count=0
  local shard_dir=""
  while IFS= read -r shard_dir
  do
    [[ -n "${shard_dir}" ]] || continue
    shard_count=$((shard_count + 1))
  done <"${shard_list}"

  [[ "${shard_count}" -gt 0 ]] || ci::fail "No shard directories found under ${shards_dir}"
  if [[ -n "${expected_shard_count}" && "${shard_count}" -ne "${expected_shard_count}" ]]
  then
    ci::fail "Expected ${expected_shard_count} shard directories for ${matrix_os}, found ${shard_count}"
  fi

  local have_meta=0
  local saved_checkout_sha=""
  local saved_event_name=""
  local saved_ref=""
  local saved_runner_os=""
  local saved_runner_arch=""
  local saved_homebrew_version=""

  local total_bottles=0
  local shard_bottles_dir="" shard_prov_dir="" manifest_path=""
  local shard_checkout_sha="" shard_event_name="" shard_ref=""
  local shard_runner_os="" shard_runner_arch="" shard_homebrew_version=""
  local shard_bottle_count=0 i=0 entry_json=""
  local formula="" pkg_version="" root_url="" rebuild="" tag=""
  local brew_fn="" rel_fn="" bottle_sha="" json_fn="" json_sha="" spdx_sha="" cdx_sha=""
  local bottle_path="" json_path="" spdx_path="" cdx_path=""
  local actual_bottle_sha="" actual_json_sha="" actual_spdx_sha="" actual_cdx_sha=""
  local shard_expected_bottles="${work_dir}/shard-expected-bottles.txt"
  local shard_expected_sboms="${work_dir}/shard-expected-sboms.txt"
  local shard_copied_jsons="${work_dir}/shard-copied-jsons.txt"
  local f="" base=""
  local -a actual_files=()

  while IFS= read -r shard_dir
  do
    [[ -n "${shard_dir}" ]] || continue
    shard_bottles_dir="${shard_dir}/bottles"
    shard_prov_dir="${shard_dir}/provenance"
    manifest_path="${shard_prov_dir}/build-manifest.json"

    [[ -d "${shard_bottles_dir}" ]] || ci::fail "Missing bottles/ directory in shard: ${shard_dir}"
    [[ -f "${manifest_path}" ]] || ci::fail "Missing provenance/build-manifest.json in shard: ${shard_dir}"

    jq -e \
      --arg head_sha "${head_sha}" \
      --arg run_id "${run_id}" \
      --arg run_attempt "${run_attempt}" \
      --arg matrix_os "${matrix_os}" \
      '
        type == "object"
        and .schema == "artagon-bottle-build-manifest/v1"
        and .head_sha == $head_sha
        and .run_id == $run_id
        and .matrix_os == $matrix_os
        and (.run_attempt | type == "string" and test("^[0-9]+$"))
        and ((.run_attempt | tonumber) >= 1 and (.run_attempt | tonumber) <= ($run_attempt | tonumber))
        and (.bottles | type == "array" and length > 0)
      ' "${manifest_path}" >/dev/null ||
      ci::fail "Invalid or mismatched shard build-manifest.json in ${shard_dir}"

    shard_checkout_sha="$(jq -r '.checkout_sha // empty' "${manifest_path}")"
    shard_event_name="$(jq -r '.event_name // ""' "${manifest_path}")"
    shard_ref="$(jq -r '.ref // ""' "${manifest_path}")"
    shard_runner_os="$(jq -r '.runner_os // ""' "${manifest_path}")"
    shard_runner_arch="$(jq -r '.runner_arch // ""' "${manifest_path}")"
    shard_homebrew_version="$(jq -r '.homebrew_version // ""' "${manifest_path}")"

    ci::require_sha40 "${shard_checkout_sha}" "shard checkout_sha (${shard_dir})"

    if [[ "${have_meta}" -eq 0 ]]
    then
      have_meta=1
      saved_checkout_sha="${shard_checkout_sha}"
      saved_event_name="${shard_event_name}"
      saved_ref="${shard_ref}"
      saved_runner_os="${shard_runner_os}"
      saved_runner_arch="${shard_runner_arch}"
      saved_homebrew_version="${shard_homebrew_version}"
    else
      [[ "${shard_checkout_sha}" = "${saved_checkout_sha}" ]] ||
        ci::fail "Mismatched checkout_sha across shards: ${shard_checkout_sha} != ${saved_checkout_sha}"
      [[ "${shard_event_name}" = "${saved_event_name}" ]] ||
        ci::fail "Mismatched event_name across shards: ${shard_event_name} != ${saved_event_name}"
      [[ "${shard_ref}" = "${saved_ref}" ]] ||
        ci::fail "Mismatched ref across shards: ${shard_ref} != ${saved_ref}"
      [[ "${shard_runner_os}" = "${saved_runner_os}" ]] ||
        ci::fail "Mismatched runner_os across shards: ${shard_runner_os} != ${saved_runner_os}"
      [[ "${shard_runner_arch}" = "${saved_runner_arch}" ]] ||
        ci::fail "Mismatched runner_arch across shards: ${shard_runner_arch} != ${saved_runner_arch}"
    fi

    : >"${shard_expected_bottles}"
    : >"${shard_expected_sboms}"
    : >"${shard_copied_jsons}"

    shard_bottle_count="$(jq '.bottles | length' "${manifest_path}")"
    ci::require_uint "${shard_bottle_count}" "shard bottle count"
    i=0
    while [[ "${i}" -lt "${shard_bottle_count}" ]]
    do
      entry_json="$(jq -c ".bottles[${i}]" "${manifest_path}")"
      formula="$(printf '%s\n' "${entry_json}" | jq -r '.formula // empty')"
      pkg_version="$(printf '%s\n' "${entry_json}" | jq -r '.pkg_version // empty')"
      root_url="$(printf '%s\n' "${entry_json}" | jq -r '.root_url // empty')"
      rebuild="$(printf '%s\n' "${entry_json}" | jq -r 'if (.rebuild | type) == "number" then (.rebuild | tostring) else "" end')"
      tag="$(printf '%s\n' "${entry_json}" | jq -r '.tag // empty')"
      brew_fn="$(printf '%s\n' "${entry_json}" | jq -r '.brew_filename // empty')"
      rel_fn="$(printf '%s\n' "${entry_json}" | jq -r '.release_filename // empty')"
      bottle_sha="$(printf '%s\n' "${entry_json}" | jq -r '.bottle_sha256 // empty')"
      json_fn="$(printf '%s\n' "${entry_json}" | jq -r '.bottle_json_filename // empty')"
      json_sha="$(printf '%s\n' "${entry_json}" | jq -r '.bottle_json_sha256 // empty')"
      spdx_sha="$(printf '%s\n' "${entry_json}" | jq -r '.spdx_sha256 // empty')"
      cdx_sha="$(printf '%s\n' "${entry_json}" | jq -r '.cdx_sha256 // empty')"

      ci::require_formula_name "${formula}" "formula"
      [[ "${pkg_version}" =~ ${PKG_VERSION_RE} && "${pkg_version}" != *".."* ]] ||
        ci::fail "Invalid pkg_version in shard manifest: ${pkg_version}"
      [[ -n "${root_url}" ]] || ci::fail "Missing root_url for ${formula} in ${shard_dir}"
      ci::require_uint "${rebuild}" "rebuild"
      ci::require_bottle_tag "${tag}" "tag"
      ci::require_safe_filename "${brew_fn}" "brew_filename"
      ci::require_safe_filename "${rel_fn}" "release_filename"
      ci::require_sha256 "${bottle_sha}" "bottle_sha256"
      ci::require_safe_filename "${json_fn}" "bottle_json_filename"
      ci::require_sha256 "${json_sha}" "bottle_json_sha256"
      ci::require_sha256 "${spdx_sha}" "spdx_sha256"
      ci::require_sha256 "${cdx_sha}" "cdx_sha256"

      if file_has_line "${formula}:${tag}" "${seen_formula_tags}"
      then
        ci::fail "Duplicate (formula, tag) across shards: (${formula}, ${tag})"
      fi
      if file_has_line "${brew_fn}" "${seen_brew_files}"
      then
        ci::fail "Duplicate bottle filename across shards: ${brew_fn}"
      fi
      if file_has_line "${rel_fn}" "${seen_release_files}"
      then
        ci::fail "Duplicate release filename across shards: ${rel_fn}"
      fi
      if ! file_has_line "${json_fn}" "${shard_copied_jsons}" && file_has_line "${json_fn}" "${seen_json_files}"
      then
        ci::fail "Duplicate bottle JSON filename across shards: ${json_fn}"
      fi

      bottle_path="${shard_bottles_dir}/${brew_fn}"
      json_path="${shard_bottles_dir}/${json_fn}"
      spdx_path="${shard_prov_dir}/${rel_fn}.spdx.json"
      cdx_path="${shard_prov_dir}/${rel_fn}.cdx.json"

      [[ -f "${bottle_path}" ]] || ci::fail "Missing bottle tarball ${brew_fn} in ${shard_dir}"
      [[ -f "${json_path}" ]] || ci::fail "Missing bottle JSON ${json_fn} in ${shard_dir}"
      [[ -f "${spdx_path}" ]] || ci::fail "Missing SPDX SBOM ${rel_fn}.spdx.json in ${shard_dir}"
      [[ -f "${cdx_path}" ]] || ci::fail "Missing CycloneDX SBOM ${rel_fn}.cdx.json in ${shard_dir}"

      actual_bottle_sha="$(ci::sha256_hex "${bottle_path}")"
      [[ "${actual_bottle_sha}" = "${bottle_sha}" ]] ||
        ci::fail "Bottle SHA-256 mismatch for ${brew_fn} in ${shard_dir}: expected ${bottle_sha}, got ${actual_bottle_sha}"

      actual_json_sha="$(ci::sha256_hex "${json_path}")"
      [[ "${actual_json_sha}" = "${json_sha}" ]] ||
        ci::fail "Bottle JSON SHA-256 mismatch for ${json_fn} in ${shard_dir}: expected ${json_sha}, got ${actual_json_sha}"

      jq -e \
        --arg formula "${formula}" \
        --arg pkg_version "${pkg_version}" \
        --arg root_url "${root_url}" \
        --argjson rebuild "${rebuild}" \
        --arg tag "${tag}" \
        --arg rel_fn "${rel_fn}" \
        --arg brew_fn "${brew_fn}" \
        --arg bottle_sha "${bottle_sha}" \
        '
          to_entries[0].value as $v
          | $v.formula.name == $formula
          and $v.formula.pkg_version == $pkg_version
          and $v.bottle.root_url == $root_url
          and $v.bottle.rebuild == $rebuild
          and $v.bottle.tags[$tag].filename == $rel_fn
          and $v.bottle.tags[$tag].local_filename == $brew_fn
          and $v.bottle.tags[$tag].sha256 == $bottle_sha
        ' "${json_path}" >/dev/null ||
        ci::fail "Bottle JSON ${json_fn} disagrees with build-manifest.json for ${formula} (${tag}) in ${shard_dir}"

      actual_spdx_sha="$(ci::sha256_hex "${spdx_path}")"
      [[ "${actual_spdx_sha}" = "${spdx_sha}" ]] ||
        ci::fail "SPDX SHA-256 mismatch for ${rel_fn}.spdx.json in ${shard_dir}: expected ${spdx_sha}, got ${actual_spdx_sha}"

      actual_cdx_sha="$(ci::sha256_hex "${cdx_path}")"
      [[ "${actual_cdx_sha}" = "${cdx_sha}" ]] ||
        ci::fail "CycloneDX SHA-256 mismatch for ${rel_fn}.cdx.json in ${shard_dir}: expected ${cdx_sha}, got ${actual_cdx_sha}"

      printf '%s:%s\n' "${formula}" "${tag}" >>"${seen_formula_tags}"
      printf '%s\n' "${brew_fn}" >>"${seen_brew_files}"
      printf '%s\n' "${rel_fn}" >>"${seen_release_files}"
      printf '%s\n' "${brew_fn}" >>"${shard_expected_bottles}"
      printf '%s\n' "${json_fn}" >>"${shard_expected_bottles}"
      printf '%s.spdx.json\n' "${rel_fn}" >>"${shard_expected_sboms}"
      printf '%s.cdx.json\n' "${rel_fn}" >>"${shard_expected_sboms}"

      cp -- "${bottle_path}" "${stage_bottles}/${brew_fn}"
      if ! file_has_line "${json_fn}" "${shard_copied_jsons}"
      then
        printf '%s\n' "${json_fn}" >>"${shard_copied_jsons}"
        printf '%s\n' "${json_fn}" >>"${seen_json_files}"
        cp -- "${json_path}" "${stage_bottles}/${json_fn}"
      fi
      cp -- "${spdx_path}" "${stage_prov}/${rel_fn}.spdx.json"
      cp -- "${cdx_path}" "${stage_prov}/${rel_fn}.cdx.json"

      printf '%s\n' "${entry_json}" >>"${entries_jsonl}"
      total_bottles=$((total_bottles + 1))
      i=$((i + 1))
    done

    shopt -s nullglob
    actual_files=("${shard_bottles_dir}"/*)
    shopt -u nullglob
    for f in ${actual_files[@]+"${actual_files[@]}"}
    do
      [[ -f "${f}" ]] || ci::fail "Unexpected non-file entry in ${shard_bottles_dir}: ${f}"
      base="$(basename "${f}")"
      file_has_line "${base}" "${shard_expected_bottles}" ||
        ci::fail "Unreferenced file in ${shard_bottles_dir}: ${base}"
    done

    shopt -s nullglob
    actual_files=("${shard_prov_dir}"/*.spdx.json "${shard_prov_dir}"/*.cdx.json)
    shopt -u nullglob
    for f in ${actual_files[@]+"${actual_files[@]}"}
    do
      base="$(basename "${f}")"
      file_has_line "${base}" "${shard_expected_sboms}" ||
        ci::fail "Unreferenced SBOM file in ${shard_prov_dir}: ${base}"
    done
  done <"${shard_list}"

  [[ "${total_bottles}" -gt 0 ]] || ci::fail "No bottles found across shards for ${matrix_os}"

  jq -s 'sort_by(.formula, .tag, .release_filename)' "${entries_jsonl}" >"${sorted_entries_json}"

  : >"${stage_prov}/SHA256SUMS"
  while IFS=$'\t' read -r bottle_sha brew_fn rel_fn
  do
    [[ -n "${bottle_sha}" ]] || continue
    printf '%s  %s\n' "${bottle_sha}" "${brew_fn}" >>"${stage_prov}/SHA256SUMS"
    printf '%s  %s\n' "${bottle_sha}" "${rel_fn}" >>"${stage_prov}/SHA256SUMS"
  done < <(jq -r '.[] | [.bottle_sha256, .brew_filename, .release_filename] | @tsv' "${sorted_entries_json}")

  jq \
    --arg head_sha "${head_sha}" \
    --arg checkout_sha "${saved_checkout_sha}" \
    --arg event_name "${saved_event_name}" \
    --arg ref "${saved_ref}" \
    --arg run_id "${run_id}" \
    --arg run_attempt "${run_attempt}" \
    --arg matrix_os "${matrix_os}" \
    --arg runner_os "${saved_runner_os}" \
    --arg runner_arch "${saved_runner_arch}" \
    --arg homebrew_version "${saved_homebrew_version}" \
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
    }' "${sorted_entries_json}" >"${stage_prov}/build-manifest.json"

  rm -rf -- "${out_dir}/bottles" "${out_dir}/provenance"
  mkdir -p -- "${out_dir}/bottles" "${out_dir}/provenance"
  cp -- "${stage_bottles}/"* "${out_dir}/bottles/"
  cp -- "${stage_prov}/"* "${out_dir}/provenance/"
}

main "$@"
