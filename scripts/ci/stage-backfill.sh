#!/usr/bin/env bash
# Stage published GitHub Release bottles and verify Homebrew provenance for `.github/workflows/attest.yml`.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland; requires brew, curl, jq, syft.
# Subcommands:
#   stage   — download published bottles, verify Formula/*.rb sha256, generate SBOMs + release-map.json
#   verify  — verify release-map.json digest and run scripts/verify-provenance.sh --require-cosign --homebrew
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${CI_DIR}/../.." && pwd -P)"
# shellcheck source=scripts/ci/common.sh
source "${CI_DIR}/common.sh"

subcmd="${1:-}"
[[ -n "${subcmd}" ]] || ci::fail "Usage: stage-backfill.sh <stage|verify>"

case "${subcmd}" in
  stage)
    ci::require_main_ref
    ci::require_repo_slug "${GITHUB_REPOSITORY:-}"
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    [[ -n "${GITHUB_OUTPUT:-}" ]] || ci::fail "GITHUB_OUTPUT is unset"

    export USER="${USER:-$(id -un)}"
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${RUNNER_TEMP}/brew-xdg}"
    mkdir -p -- "${XDG_CONFIG_HOME}"
    brew trust --tap artagon/aitools

    target_list=()
    if [[ -n "${FORMULAE:-}" ]]
    then
      read -r -a requested <<<"${FORMULAE}"
      for name in ${requested[@]+"${requested[@]}"}
      do
        ci::require_formula_name "${name}" "formula"
        [[ -f "${REPO_ROOT}/Formula/${name}.rb" ]] || ci::fail "Formula/${name}.rb does not exist"
        target_list+=("${name}")
      done
    else
      for rb in "${REPO_ROOT}"/Formula/*.rb
      do
        name="$(basename "${rb}" .rb)"
        if grep -Eq '^[[:space:]]*bottle do$' "${rb}"
        then
          target_list+=("${name}")
        fi
      done
    fi
    [[ "${#target_list[@]}" -gt 0 ]] || ci::fail "No bottled formulae selected"

    parsed_json="${RUNNER_TEMP}/parsed-bottles.json"
    tsv_path="${RUNNER_TEMP}/bottles.tsv"
    bash "${REPO_ROOT}/scripts/verify-provenance.sh" --parse-only --all-tags --json "${target_list[@]}" >"${parsed_json}"
    jq -r '
      .results[]
      | [.formula, .pkg_version, .root_url, (.rebuild | tostring), .bottle_tag, .brew_filename, .release_filename, .expected_sha256]
      | @tsv
    ' "${parsed_json}" >"${tsv_path}"

    stage_dir="${RUNNER_TEMP}/attest-stage"
    rm -rf -- "${stage_dir}"
    mkdir -p -- "${stage_dir}/files"
    entries_jsonl="${RUNNER_TEMP}/map-entries.jsonl"
    : >"${entries_jsonl}"

    while IFS=$'\t' read -r formula pkg_version root_url rebuild tag brew_fn rel_fn expected_sha
    do
      ci::require_formula_name "${formula}" "formula"
      ci::require_safe_filename "${brew_fn}" "brew_filename"
      ci::require_safe_filename "${rel_fn}" "release_filename"
      ci::require_sha256 "${expected_sha}" "expected_sha256"
      ci::require_uint "${rebuild}" "rebuild"

      release_tag="${formula}-${pkg_version}"
      expected_root="https://github.com/${GITHUB_REPOSITORY}/releases/download/${release_tag}"
      [[ "${root_url}" = "${expected_root}" ]] ||
        ci::fail "Unexpected root_url ${root_url} in Formula/${formula}.rb (expected ${expected_root})"

      bottle_dest="${stage_dir}/files/${rel_fn}"
      curl --disable --fail --location --silent --show-error --retry 3 \
        --output "${bottle_dest}" \
        "${root_url}/${rel_fn}"

      actual_sha="$(ci::sha256_hex "${bottle_dest}")"
      [[ "${actual_sha}" = "${expected_sha}" ]] ||
        ci::fail "Downloaded bottle ${rel_fn} digest mismatch: expected ${expected_sha}, got ${actual_sha}"

      spdx_dest="${stage_dir}/files/${rel_fn}.spdx.json"
      cdx_dest="${stage_dir}/files/${rel_fn}.cdx.json"
      syft scan "file:${bottle_dest}" \
        --source-name "${formula}" \
        --source-version "${pkg_version}" \
        --select-catalogers "+javascript-package-cataloger" \
        -o "spdx-json=${spdx_dest}" \
        -o "cyclonedx-json=${cdx_dest}"

      spdx_sha="$(ci::sha256_hex "${spdx_dest}")"
      cdx_sha="$(ci::sha256_hex "${cdx_dest}")"

      jq -c -n \
        --arg formula "${formula}" \
        --arg pkg_version "${pkg_version}" \
        --arg release_tag "${release_tag}" \
        --arg root_url "${root_url}" \
        --argjson rebuild "${rebuild}" \
        --arg tag "${tag}" \
        --arg brew_filename "${brew_fn}" \
        --arg release_filename "${rel_fn}" \
        --arg bottle_sha256 "${actual_sha}" \
        --arg spdx_sha256 "${spdx_sha}" \
        --arg cdx_sha256 "${cdx_sha}" \
        '{
          formula: $formula,
          pkg_version: $pkg_version,
          release_tag: $release_tag,
          root_url: $root_url,
          rebuild: $rebuild,
          tag: $tag,
          brew_filename: $brew_filename,
          release_filename: $release_filename,
          bottle_sha256: $bottle_sha256,
          spdx_sha256: $spdx_sha256,
          cdx_sha256: $cdx_sha256
        }' >>"${entries_jsonl}"
    done <"${tsv_path}"

    jq -s '{
      schema: "artagon-bottle-release-map/v1",
      bottles: .
    }' "${entries_jsonl}" >"${stage_dir}/release-map.json"

    map_sha="$(ci::sha256_hex "${stage_dir}/release-map.json")"
    printf 'release_map_sha256=%s\n' "${map_sha}" >>"${GITHUB_OUTPUT}"
    ;;

  verify)
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    ci::require_sha256 "${RELEASE_MAP_SHA256:-}" "RELEASE_MAP_SHA256"

    stage_dir="${RUNNER_TEMP}/attest-stage"
    [[ -f "${stage_dir}/release-map.json" ]] || ci::fail "Missing ${stage_dir}/release-map.json"
    actual_sha="$(ci::sha256_hex "${stage_dir}/release-map.json")"
    [[ "${actual_sha}" = "${RELEASE_MAP_SHA256}" ]] ||
      ci::fail "release-map.json digest mismatch: expected ${RELEASE_MAP_SHA256}, got ${actual_sha}"

    formulae=()
    while IFS= read -r formula
    do
      if [[ -n "${formula}" ]]
      then
        ci::require_formula_name "${formula}" "formula"
        formulae+=("${formula}")
      fi
    done < <(jq -r '.bottles[].formula' "${stage_dir}/release-map.json" | sort -u)
    [[ "${#formulae[@]}" -gt 0 ]] || ci::fail "Empty bottle list in release-map.json"

    bash "${REPO_ROOT}/scripts/verify-provenance.sh" --all-tags --require-cosign --homebrew "${formulae[@]}"
    ;;

  *)
    ci::fail "Unknown subcommand: ${subcmd}"
    ;;
esac
