#!/usr/bin/env bash
# Stage, validate, publish, and verify bottle pull requests for `.github/workflows/publish.yml`.
#
# Target contract: Bash 3.2+ executable; Linux GNU + macOS BSD userland; requires brew, git, gh, jq, python3, unzip.
# Security boundary:
# - Workflow steps copy `scripts/` from `refs/heads/main` into `${RUNNER_TEMP}/trusted-scripts`
#   before applying any PR commits (`brew pr-pull` or `git am`), and invoke this script from
#   that trusted copy so PR diffs cannot alter running CI code.
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPTS_DIR="$(cd "${CI_DIR}/.." && pwd -P)"
# shellcheck source=scripts/ci/common.sh
source "${CI_DIR}/common.sh"

subcmd="${1:-}"
[[ -n "${subcmd}" ]] || ci::fail "Usage: publish-bottles.sh <subcommand>"

case "${subcmd}" in
  validate)
    ci::require_main_ref
    ci::require_repo_slug "${GITHUB_REPOSITORY:-}"
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    [[ -n "${GITHUB_OUTPUT:-}" ]] || ci::fail "GITHUB_OUTPUT is unset"
    ci::require_uint "${PULL_REQUEST:-}" "pull_request"
    ci::require_sha40 "${HEAD_SHA:-}" "head_sha"

    allow_missing="${ALLOW_MISSING_MANIFEST:-false}"
    allow_workflows="${ALLOW_WORKFLOW_CHANGES:-false}"
    ci::require_bool "${allow_missing}" "allow_missing_manifest"
    ci::require_bool "${allow_workflows}" "allow_workflow_changes"

    pr="$(gh pr view "${PULL_REQUEST}" --repo "${GITHUB_REPOSITORY}" \
      --json state,isCrossRepository,baseRefName,headRefOid)"
    [[ "$(printf '%s\n' "${pr}" | jq -r .state)" = "OPEN" ]] ||
      ci::fail "Pull request #${PULL_REQUEST} is not open"
    [[ "$(printf '%s\n' "${pr}" | jq -r .isCrossRepository)" = "false" ]] ||
      ci::fail "Refusing to publish bottles built from a fork"
    [[ "$(printf '%s\n' "${pr}" | jq -r .baseRefName)" = "main" ]] ||
      ci::fail "The pull request must target main"
    [[ "$(printf '%s\n' "${pr}" | jq -r .headRefOid)" = "${HEAD_SHA}" ]] ||
      ci::fail "The pull request head is not ${HEAD_SHA}"

    cmp_json="$(gh api "repos/${GITHUB_REPOSITORY}/compare/main...${HEAD_SHA}")"
    behind="$(printf '%s\n' "${cmp_json}" | jq -r .behind_by)"
    [[ "${behind}" = "0" ]] ||
      ci::fail "The pull request is ${behind} commits behind main; update it and rerun tests"

    if [[ "${allow_workflows}" != "true" ]]
    then
      if printf '%s\n' "${cmp_json}" | jq -e 'any(.files[]; (.filename | startswith(".github/workflows/")) or (.filename | startswith("scripts/ci/")))' >/dev/null
      then
        ci::fail "Pull request #${PULL_REQUEST} modifies .github/workflows/ or scripts/ci/; pass allow_workflow_changes=true only after auditing diffs"
      fi
    fi

    run_obj="$(
      gh api "repos/${GITHUB_REPOSITORY}/actions/workflows/tests.yml/runs?head_sha=${HEAD_SHA}&per_page=100" |
        jq -c --arg repo "${GITHUB_REPOSITORY}" \
          '[.workflow_runs[] | select(.head_repository.full_name == $repo)] | sort_by(.created_at) | last // empty'
    )"
    [[ -n "${run_obj}" ]] || ci::fail "No tests.yml run found for ${HEAD_SHA}"
    conclusion="$(printf '%s\n' "${run_obj}" | jq -r '.conclusion // "missing"')"
    [[ "${conclusion}" = "success" ]] ||
      ci::fail "Newest tests.yml run for ${HEAD_SHA} is ${conclusion}, not success"

    test_run_id="$(printf '%s\n' "${run_obj}" | jq -r '.id | tostring')"
    ci::require_uint "${test_run_id}" "test_run_id"
    printf 'test_run_id=%s\n' "${test_run_id}" >>"${GITHUB_OUTPUT}"

    arts_json="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${test_run_id}/artifacts?per_page=100")"
    bottles_art="$(printf '%s\n' "${arts_json}" | jq -c '[.artifacts[] | select(.name == "bottles_macos-26" and .expired == false)] | first // empty')"
    [[ -n "${bottles_art}" ]] || ci::fail "Run ${test_run_id} has no active bottles_macos-26 artifact"

    bottles_id="$(printf '%s\n' "${bottles_art}" | jq -r '.id | tostring')"
    ci::require_uint "${bottles_id}" "bottles artifact id"
    bottles_digest="$(printf '%s\n' "${bottles_art}" | jq -r '.digest // empty')"
    [[ "${bottles_digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || ci::fail "bottles_macos-26 missing sha256 digest"

    rm -rf -- "${RUNNER_TEMP}/verified-bottles" "${RUNNER_TEMP}/verified-provenance"
    mkdir -p -- "${RUNNER_TEMP}/verified-bottles" "${RUNNER_TEMP}/verified-provenance"
    gh api "repos/${GITHUB_REPOSITORY}/actions/artifacts/${bottles_id}/zip" >"${RUNNER_TEMP}/bottles.zip"
    [[ "sha256:$(ci::sha256_hex "${RUNNER_TEMP}/bottles.zip")" = "${bottles_digest}" ]] ||
      ci::fail "bottles_macos-26 ZIP digest mismatch"
    unzip -q "${RUNNER_TEMP}/bottles.zip" -d "${RUNNER_TEMP}/verified-bottles"

    prov_art="$(printf '%s\n' "${arts_json}" | jq -c '[.artifacts[] | select(.name == "provenance_macos-26" and .expired == false)] | first // empty')"
    if [[ -n "${prov_art}" ]]
    then
      prov_id="$(printf '%s\n' "${prov_art}" | jq -r '.id | tostring')"
      ci::require_uint "${prov_id}" "provenance artifact id"
      prov_digest="$(printf '%s\n' "${prov_art}" | jq -r '.digest // empty')"
      [[ "${prov_digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || ci::fail "provenance_macos-26 missing sha256 digest"
      gh api "repos/${GITHUB_REPOSITORY}/actions/artifacts/${prov_id}/zip" >"${RUNNER_TEMP}/provenance.zip"
      [[ "sha256:$(ci::sha256_hex "${RUNNER_TEMP}/provenance.zip")" = "${prov_digest}" ]] ||
        ci::fail "provenance_macos-26 ZIP digest mismatch"
      unzip -q "${RUNNER_TEMP}/provenance.zip" -d "${RUNNER_TEMP}/verified-provenance"
    elif [[ "${allow_missing}" != "true" ]]
    then
      ci::fail "Run ${test_run_id} has no active provenance_macos-26 artifact (set allow_missing_manifest=true only for pre-provenance PRs)"
    fi
    ;;

  stage)
    ci::require_main_ref
    ci::require_repo_slug "${GITHUB_REPOSITORY:-}"
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    [[ -n "${GITHUB_OUTPUT:-}" ]] || ci::fail "GITHUB_OUTPUT is unset"
    ci::require_uint "${PULL_REQUEST:-}" "pull_request"
    ci::require_sha40 "${HEAD_SHA:-}" "head_sha"
    ci::require_uint "${TEST_RUN_ID:-}" "test_run_id"

    export USER="${USER:-$(id -un)}"
    base_main_sha="$(git rev-parse HEAD)"
    ci::require_sha40 "${base_main_sha}" "base_main_sha"
    printf 'base_main_sha=%s\n' "${base_main_sha}" >>"${GITHUB_OUTPUT}"

    brew pr-pull --debug --no-upload --tap="${GITHUB_REPOSITORY}" --head-sha="${HEAD_SHA}" \
      "${PULL_REQUEST}"

    (
      cd "${RUNNER_TEMP}/verified-bottles"
      shopt -s nullglob
      json_files=(./*.bottle.json)
      shopt -u nullglob
      [[ "${#json_files[@]}" -gt 0 ]] || ci::fail "No *.bottle.json files in verified bottles_macos-26 artifact"
      brew bottle --merge --write "${json_files[@]}"
    )

    stage_dir="${RUNNER_TEMP}/publish-stage"
    rm -rf -- "${stage_dir}"
    mkdir -p -- "${stage_dir}/files"
    entries_jsonl="${RUNNER_TEMP}/map-entries.jsonl"
    : >"${entries_jsonl}"
    expected_formula_paths=()

    shopt -s nullglob
    json_files=("${RUNNER_TEMP}/verified-bottles"/*.bottle.json)
    shopt -u nullglob

    for json_file in ${json_files[@]+"${json_files[@]}"}
    do
      formula_name="$(jq -r 'to_entries[0].value.formula.name' "${json_file}")"
      pkg_version="$(jq -r 'to_entries[0].value.formula.pkg_version' "${json_file}")"
      root_url="$(jq -r 'to_entries[0].value.bottle.root_url' "${json_file}")"
      rebuild="$(jq -r 'to_entries[0].value.bottle.rebuild' "${json_file}")"

      ci::require_formula_name "${formula_name}" "formula.name"
      ci::require_uint "${rebuild}" "bottle.rebuild"

      release_tag="${formula_name}-${pkg_version}"
      expected_root_url="https://github.com/${GITHUB_REPOSITORY}/releases/download/${release_tag}"
      [[ "${root_url}" = "${expected_root_url}" ]] ||
        ci::fail "Unexpected root_url ${root_url} (expected ${expected_root_url})"

      expected_formula_paths+=("Formula/${formula_name}.rb")
      brew audit --skip-style "artagon/aitools/${formula_name}"

      while IFS=$'\t' read -r tag rel_fn brew_fn expected_sha
      do
        ci::require_safe_filename "${rel_fn}" "release_filename"
        ci::require_safe_filename "${brew_fn}" "brew_filename"
        ci::require_sha256 "${expected_sha}" "expected_sha"

        bottle_file="${RUNNER_TEMP}/verified-bottles/${brew_fn}"
        [[ -f "${bottle_file}" ]] || ci::fail "Missing bottle file ${bottle_file}"
        actual_sha="$(ci::sha256_hex "${bottle_file}")"
        [[ "${actual_sha}" = "${expected_sha}" ]] ||
          ci::fail "Bottle digest mismatch on ${brew_fn}: expected ${expected_sha}, got ${actual_sha}"

        grep -Fq "${expected_sha}" "Formula/${formula_name}.rb" ||
          ci::fail "Formula/${formula_name}.rb does not contain merged bottle sha256 ${expected_sha}"

        spdx_src="${RUNNER_TEMP}/verified-provenance/${rel_fn}.spdx.json"
        cdx_src="${RUNNER_TEMP}/verified-provenance/${rel_fn}.cdx.json"
        if [[ -f "${RUNNER_TEMP}/verified-provenance/build-manifest.json" ]]
        then
          [[ -f "${spdx_src}" && -f "${cdx_src}" ]] ||
            ci::fail "Missing SBOM files for ${rel_fn} in provenance_macos-26"
          spdx_sha="$(ci::sha256_hex "${spdx_src}")"
          cdx_sha="$(ci::sha256_hex "${cdx_src}")"
          jq -e \
            --arg head "${HEAD_SHA}" \
            --arg run_id "${TEST_RUN_ID}" \
            --arg formula "${formula_name}" \
            --arg brew_fn "${brew_fn}" \
            --arg rel_fn "${rel_fn}" \
            --arg bottle_sha "${actual_sha}" \
            --arg spdx_sha "${spdx_sha}" \
            --arg cdx_sha "${cdx_sha}" \
            '.head_sha == $head and .run_id == $run_id and any(.bottles[];
              .formula == $formula
              and .brew_filename == $brew_fn
              and .release_filename == $rel_fn
              and .bottle_sha256 == $bottle_sha
              and .spdx_sha256 == $spdx_sha
              and .cdx_sha256 == $cdx_sha
            )' "${RUNNER_TEMP}/verified-provenance/build-manifest.json" >/dev/null ||
            ci::fail "build-manifest.json cross-check failed for ${rel_fn}"
        else
          spdx_src="${RUNNER_TEMP}/generated-${rel_fn}.spdx.json"
          cdx_src="${RUNNER_TEMP}/generated-${rel_fn}.cdx.json"
          syft scan "file:${bottle_file}" \
            --source-name "${formula_name}" \
            --source-version "${pkg_version}" \
            --select-catalogers "+javascript-package-cataloger" \
            -o "spdx-json=${spdx_src}" \
            -o "cyclonedx-json=${cdx_src}"
          spdx_sha="$(ci::sha256_hex "${spdx_src}")"
          cdx_sha="$(ci::sha256_hex "${cdx_src}")"
        fi

        cp -- "${bottle_file}" "${stage_dir}/files/${rel_fn}"
        cp -- "${spdx_src}" "${stage_dir}/files/${rel_fn}.spdx.json"
        cp -- "${cdx_src}" "${stage_dir}/files/${rel_fn}.cdx.json"

        jq -c -n \
          --arg formula "${formula_name}" \
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
      done < <(
        jq -r '
          to_entries[0].value.bottle.tags
          | to_entries[]
          | [.key, .value.filename, .value.local_filename, .value.sha256]
          | @tsv
        ' "${json_file}"
      )
    done

    git fetch --no-tags origin "${HEAD_SHA}"

    while IFS= read -r pr_formula_path
    do
      [[ -z "${pr_formula_path}" ]] && continue
      covered=0
      for bottled in "${expected_formula_paths[@]}"
      do
        if [[ "${pr_formula_path}" = "${bottled}" ]]
        then
          covered=1
          break
        fi
      done
      [[ "${covered}" -eq 1 ]] ||
        ci::fail "Changed formula ${pr_formula_path} is not covered by bottles_macos-26 from run ${TEST_RUN_ID}"
    done < <(git diff --name-only --diff-filter=ACMR "${base_main_sha}" "${HEAD_SHA}" -- 'Formula/*.rb')

    if [[ -f README.md ]] && grep -Fq "<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->" README.md
    then
      repo_cwd="$(pwd -P)"
      PROVENANCE_REPO_ROOT="${repo_cwd}" README_BOTTLES_FILE="${repo_cwd}/README.md" \
        bash "${SCRIPTS_DIR}/update-readme-bottles.sh"
      if ! git diff --quiet -- README.md
      then
        git add -- README.md
        git commit --message "docs(readme): refresh bottle versions and provenance links"
      fi
    fi

    while IFS= read -r changed_path
    do
      [[ -z "${changed_path}" ]] && continue
      if [[ "${changed_path}" = "README.md" ]]
      then
        continue
      fi
      matched=0
      for allowed in "${expected_formula_paths[@]}"
      do
        if [[ "${changed_path}" = "${allowed}" ]]
        then
          matched=1
          break
        fi
      done
      [[ "${matched}" -eq 1 ]] || ci::fail "Unexpected tree difference outside bottled formulae: ${changed_path}"
    done < <(git diff --name-only "${HEAD_SHA}" HEAD)

    git format-patch --stdout "${base_main_sha}..HEAD" >"${stage_dir}/commits.mbox"
    [[ -s "${stage_dir}/commits.mbox" ]] || ci::fail "commits.mbox is empty"

    jq -s '{
      schema: "artagon-bottle-release-map/v1",
      bottles: .
    }' "${entries_jsonl}" >"${stage_dir}/release-map.json"

    map_sha="$(ci::sha256_hex "${stage_dir}/release-map.json")"
    printf 'release_map_sha256=%s\n' "${map_sha}" >>"${GITHUB_OUTPUT}"
    ;;

  verify-patch-policy)
    ci::require_main_ref
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    ci::require_sha40 "${BASE_MAIN_SHA:-}" "BASE_MAIN_SHA"
    ci::require_sha40 "${HEAD_SHA:-}" "HEAD_SHA"
    ci::require_sha256 "${RELEASE_MAP_SHA256:-}" "RELEASE_MAP_SHA256"

    current_sha="$(git rev-parse HEAD)"
    [[ "${current_sha}" = "${BASE_MAIN_SHA}" ]] ||
      ci::fail "main moved from ${BASE_MAIN_SHA} to ${current_sha} during signing; aborting without rebasing"

    stage_dir="${RUNNER_TEMP}/publish-stage"
    actual_map_sha="$(ci::sha256_hex "${stage_dir}/release-map.json")"
    [[ "${actual_map_sha}" = "${RELEASE_MAP_SHA256}" ]] ||
      ci::fail "release-map.json digest mismatch in push-main"

    git am "${stage_dir}/commits.mbox"
    git merge-base --is-ancestor "${BASE_MAIN_SHA}" HEAD ||
      ci::fail "Applied patch series does not descend from ${BASE_MAIN_SHA}"

    if [[ -z "${SKIP_FETCH_HEAD_SHA:-}" ]]
    then
      git fetch --no-tags origin "${HEAD_SHA}"
    fi

    repo_cwd="$(pwd -P)"
    while IFS= read -r changed_path
    do
      [[ -z "${changed_path}" ]] && continue
      if [[ "${changed_path}" = "README.md" ]]
      then
        python3 "${CI_DIR}/verify_patch_policy.py" verify-readme-git "${HEAD_SHA}" ||
          ci::fail "README.md modified outside BOTTLE_PROVENANCE_TABLE markers"
        PROVENANCE_REPO_ROOT="${repo_cwd}" README_BOTTLES_FILE="${repo_cwd}/README.md" \
          bash "${SCRIPTS_DIR}/update-readme-bottles.sh" --check ||
          ci::fail "README.md bottle provenance table does not match Formula/*.rb"
        continue
      fi

      jq -e --arg path "${changed_path}" \
        'any(.bottles[]; ("Formula/" + .formula + ".rb") == $path)' \
        "${stage_dir}/release-map.json" >/dev/null ||
        ci::fail "Refusing to push unexpected file modification relative to reviewed HEAD_SHA: ${changed_path}"

      python3 "${CI_DIR}/verify_patch_policy.py" verify-formula-git "${HEAD_SHA}" "${changed_path}" ||
        ci::fail "Patch diff relative to HEAD_SHA modifies lines outside bottle do ... end in ${changed_path}"
    done < <(git diff --name-only "${HEAD_SHA}" HEAD)
    ;;

  publish-releases)
    ci::require_repo_slug "${GITHUB_REPOSITORY:-}"
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    stage_dir="${RUNNER_TEMP}/publish-stage"
    while IFS= read -r release_tag
    do
      [[ -z "${release_tag}" ]] && continue
      ci::require_safe_filename "${release_tag}" "release_tag"
      draft_id="$(
        gh api "repos/${GITHUB_REPOSITORY}/releases?per_page=100" |
          jq -r --arg tag "${release_tag}" '[.[] | select(.draft == true and .tag_name == $tag)] | first | .id // empty'
      )"
      if [[ -n "${draft_id}" ]]
      then
        gh release edit "${release_tag}" --repo "${GITHUB_REPOSITORY}" --draft=false
      fi
    done < <(jq -r '.bottles[].release_tag' "${stage_dir}/release-map.json" | sort -u)
    ;;

  cleanup-drafts)
    ci::require_repo_slug "${GITHUB_REPOSITORY:-}"
    stage_dir="${RUNNER_TEMP:-}/publish-stage"
    [[ -f "${stage_dir}/release-map.json" ]] || exit 0
    while IFS= read -r release_tag
    do
      [[ -z "${release_tag}" ]] && continue
      ci::require_safe_filename "${release_tag}" "release_tag"
      draft_id="$(
        gh api "repos/${GITHUB_REPOSITORY}/releases?per_page=100" |
          jq -r --arg tag "${release_tag}" '[.[] | select(.draft == true and .tag_name == $tag)] | first | .id // empty'
      )"
      if [[ -n "${draft_id}" ]]
      then
        ci::require_uint "${draft_id}" "draft release id"
        gh api -X DELETE "repos/${GITHUB_REPOSITORY}/releases/${draft_id}"
      fi
    done < <(jq -r '.bottles[].release_tag' "${stage_dir}/release-map.json" | sort -u)
    ;;

  verify-homebrew)
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    export USER="${USER:-$(id -un)}"
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${RUNNER_TEMP}/brew-verify-xdg}"
    mkdir -p -- "${XDG_CONFIG_HOME}"
    brew trust --tap artagon/aitools

    stage_dir="${RUNNER_TEMP}/publish-stage"
    while IFS= read -r formula
    do
      [[ -z "${formula}" ]] && continue
      ci::require_formula_name "${formula}" "formula"
      verify_out="${RUNNER_TEMP}/brew-verify-${formula}.json"
      brew verify \
        --bottle-tag=arm64_tahoe \
        --force \
        --json \
        "artagon/aitools/${formula}" >"${verify_out}"
      jq -e 'type == "array" and length == 1' "${verify_out}" >/dev/null
    done < <(jq -r '.bottles[].formula' "${stage_dir}/release-map.json" | sort -u)
    ;;

  close-pr)
    ci::require_repo_slug "${GITHUB_REPOSITORY:-}"
    ci::require_uint "${PULL_REQUEST:-}" "pull_request"
    ci::require_sha40 "${HEAD_SHA:-}" "head_sha"

    published_sha="$(git rev-parse HEAD)"
    ci::require_sha40 "${published_sha}" "published_sha"
    pr="$(gh pr view "${PULL_REQUEST}" --repo "${GITHUB_REPOSITORY}" \
      --json state,isCrossRepository,baseRefName,headRefOid)"
    if [[ "$(printf '%s\n' "${pr}" | jq -r .state)" = "OPEN" &&
       "$(printf '%s\n' "${pr}" | jq -r .isCrossRepository)" = "false" &&
       "$(printf '%s\n' "${pr}" | jq -r .baseRefName)" = "main" &&
       "$(printf '%s\n' "${pr}" | jq -r .headRefOid)" = "${HEAD_SHA}" ]]
    then
      gh pr close "${PULL_REQUEST}" \
        --repo "${GITHUB_REPOSITORY}" \
        --comment "Published bottles and build provenance on \`main\` at ${published_sha} (from reviewed head ${HEAD_SHA})."
    fi
    ;;

  *)
    ci::fail "Unknown subcommand: ${subcmd}"
    ;;
esac
