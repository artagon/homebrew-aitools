#!/usr/bin/env bash
# Isolated OIDC signing, attestation, self-verification, and release upload helpers
# for `.github/workflows/sign-bottles.yml` (@refs/heads/main).
#
# Target contract: Bash 3.2+ executable; Linux GNU + macOS BSD userland; requires gh, jq, cosign, unzip, base64.
# Subcommands:
#   prepare          — validate inputs, builder run, and release map; stage dual subjects + lineage.json
#   sign-and-verify  — sign Sigstore cosign v3 bundles and self-verify all 5 attestation/signature gates
#   upload           — upload bottles (publish mode) and 8 provenance sidecars to GitHub Releases
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/ci/common.sh
source "${CI_DIR}/common.sh"

subcmd="${1:-}"
[[ -n "${subcmd}" ]] || ci::fail "Usage: sign-and-attest.sh <prepare|sign-and-verify|upload>"

ci::require_main_ref
ci::require_repo_slug "${GITHUB_REPOSITORY:-}"
ci::require_sha40 "${GITHUB_SHA:-}" "GITHUB_SHA"

case "${subcmd}" in
  prepare)
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    [[ "${MODE:-}" = "publish" || "${MODE:-}" = "backfill" ]] ||
      ci::fail "MODE must be publish or backfill (got: ${MODE:-})"
    ci::require_sha256 "${RELEASE_MAP_SHA256:-}" "RELEASE_MAP_SHA256"
    allow_missing="${ALLOW_MISSING_MANIFEST:-false}"
    ci::require_bool "${allow_missing}" "ALLOW_MISSING_MANIFEST"

    [[ -f stage/release-map.json ]] || ci::fail "stage/release-map.json is missing"
    actual_map_sha="$(ci::sha256_hex stage/release-map.json)"
    [[ "${actual_map_sha}" = "${RELEASE_MAP_SHA256}" ]] ||
      ci::fail "release-map.json SHA-256 mismatch: expected ${RELEASE_MAP_SHA256}, got ${actual_map_sha}"

    jq -e '.schema == "artagon-bottle-release-map/v1" and (.bottles | type == "array" and length > 0)' \
      stage/release-map.json >/dev/null || ci::fail "Invalid release-map.json schema or empty bottle list"

    builder_head_sha=""
    builder_workflow=""
    builder_run_id=""
    builder_run_attempt=""
    prov_artifact_digest=""
    lineage_status="backfill-unverified"

    if [[ "${MODE}" = "publish" ]]
    then
      ci::require_sha40 "${HEAD_SHA:-}" "HEAD_SHA"
      ci::require_uint "${TEST_RUN_ID:-}" "TEST_RUN_ID"

      run_json="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${TEST_RUN_ID}")"
      [[ "$(printf '%s\n' "${run_json}" | jq -r .path)" = ".github/workflows/tests.yml" ]] ||
        ci::fail "Run ${TEST_RUN_ID} is not .github/workflows/tests.yml"
      [[ "$(printf '%s\n' "${run_json}" | jq -r .head_repository.full_name)" = "${GITHUB_REPOSITORY}" ]] ||
        ci::fail "Run ${TEST_RUN_ID} is not from ${GITHUB_REPOSITORY}"
      api_run_head_sha="$(printf '%s\n' "${run_json}" | jq -r .head_sha)"
      [[ "${api_run_head_sha}" = "${HEAD_SHA}" ]] ||
        ci::fail "Run ${TEST_RUN_ID} ran on ${api_run_head_sha}, not reviewed HEAD_SHA ${HEAD_SHA}"
      [[ "$(printf '%s\n' "${run_json}" | jq -r .conclusion)" = "success" ]] ||
        ci::fail "Run ${TEST_RUN_ID} did not conclude with success"
      run_event="$(printf '%s\n' "${run_json}" | jq -r .event)"
      [[ "${run_event}" = "pull_request" || "${run_event}" = "workflow_dispatch" ]] ||
        ci::fail "Unexpected event ${run_event} on run ${TEST_RUN_ID}"

      builder_head_sha="${HEAD_SHA}"
      builder_workflow=".github/workflows/tests.yml"
      builder_run_id="${TEST_RUN_ID}"
      builder_run_attempt="$(printf '%s\n' "${run_json}" | jq -r '.run_attempt | tostring')"

      arts_json="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${TEST_RUN_ID}/artifacts?per_page=100")"
      prov_art="$(printf '%s\n' "${arts_json}" | jq -c '[.artifacts[] | select(.name == "provenance_macos-26" and .expired == false)] | first // empty')"

      if [[ -z "${prov_art}" ]]
      then
        if [[ "${allow_missing}" = "true" ]]
        then
          lineage_status="publish-legacy-no-manifest"
          printf '::warning::Allowing missing provenance_macos-26 on run %s via explicit override\n' "${TEST_RUN_ID}"
          if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]
          then
            printf '### Provenance override: missing provenance_macos-26 allowed on run %s\n' "${TEST_RUN_ID}" >>"${GITHUB_STEP_SUMMARY}"
          fi
        else
          ci::fail "Run ${TEST_RUN_ID} has no active provenance_macos-26 artifact (set allow_missing_manifest=true only for pre-provenance PRs)"
        fi
      else
        lineage_status="verified-builder-manifest"
        prov_id="$(printf '%s\n' "${prov_art}" | jq -r '.id | tostring')"
        ci::require_uint "${prov_id}" "provenance artifact id"
        prov_artifact_digest="$(printf '%s\n' "${prov_art}" | jq -r '.digest // empty')"
        [[ "${prov_artifact_digest}" =~ ^sha256:[0-9a-f]{64}$ ]] ||
          ci::fail "Artifact ${prov_id} missing valid sha256 digest: ${prov_artifact_digest}"

        gh api "repos/${GITHUB_REPOSITORY}/actions/artifacts/${prov_id}/zip" >"${RUNNER_TEMP}/verified-prov.zip"
        zip_sha="sha256:$(ci::sha256_hex "${RUNNER_TEMP}/verified-prov.zip")"
        [[ "${zip_sha}" = "${prov_artifact_digest}" ]] ||
          ci::fail "Artifact ${prov_id} digest mismatch: expected ${prov_artifact_digest}, got ${zip_sha}"

        unzip -p "${RUNNER_TEMP}/verified-prov.zip" build-manifest.json >"${RUNNER_TEMP}/verified-build-manifest.json"
        jq -e \
          --arg head "${HEAD_SHA}" \
          --arg run_id "${TEST_RUN_ID}" \
          '.schema == "artagon-bottle-build-manifest/v1" and .head_sha == $head and .run_id == $run_id' \
          "${RUNNER_TEMP}/verified-build-manifest.json" >/dev/null ||
          ci::fail "build-manifest.json head_sha or run_id does not match ${HEAD_SHA} / ${TEST_RUN_ID}"
      fi
    fi

    mkdir -p -- work out
    : >work/subject-checksums.txt

    bottle_count="$(jq '.bottles | length' stage/release-map.json)"
    ci::require_uint "${bottle_count}" "bottle_count"
    i=0
    while [[ "${i}" -lt "${bottle_count}" ]]
    do
      entry="$(jq -c ".bottles[${i}]" stage/release-map.json)"
      formula="$(printf '%s\n' "${entry}" | jq -r .formula)"
      pkg_version="$(printf '%s\n' "${entry}" | jq -r .pkg_version)"
      release_tag="$(printf '%s\n' "${entry}" | jq -r .release_tag)"
      brew_fn="$(printf '%s\n' "${entry}" | jq -r .brew_filename)"
      rel_fn="$(printf '%s\n' "${entry}" | jq -r .release_filename)"
      bottle_sha="$(printf '%s\n' "${entry}" | jq -r .bottle_sha256)"
      spdx_sha="$(printf '%s\n' "${entry}" | jq -r .spdx_sha256)"
      cdx_sha="$(printf '%s\n' "${entry}" | jq -r .cdx_sha256)"

      ci::require_formula_name "${formula}" "formula"
      [[ "${pkg_version}" =~ ^[0-9A-Za-z._+-]+$ ]] || ci::fail "Invalid pkg_version: ${pkg_version}"
      [[ "${release_tag}" = "${formula}-${pkg_version}" ]] || ci::fail "Unexpected release_tag ${release_tag}"
      ci::require_safe_filename "${brew_fn}" "brew_filename"
      ci::require_safe_filename "${rel_fn}" "release_filename"
      ci::require_sha256 "${bottle_sha}" "bottle_sha256"
      ci::require_sha256 "${spdx_sha}" "spdx_sha256"
      ci::require_sha256 "${cdx_sha}" "cdx_sha256"

      [[ -f "stage/files/${rel_fn}" ]] || ci::fail "Missing staged bottle stage/files/${rel_fn}"
      [[ -f "stage/files/${rel_fn}.spdx.json" ]] || ci::fail "Missing staged SPDX stage/files/${rel_fn}.spdx.json"
      [[ -f "stage/files/${rel_fn}.cdx.json" ]] || ci::fail "Missing staged CycloneDX stage/files/${rel_fn}.cdx.json"

      [[ "$(ci::sha256_hex "stage/files/${rel_fn}")" = "${bottle_sha}" ]] ||
        ci::fail "Staged bottle digest mismatch for ${rel_fn}"
      [[ "$(ci::sha256_hex "stage/files/${rel_fn}.spdx.json")" = "${spdx_sha}" ]] ||
        ci::fail "Staged SPDX digest mismatch for ${rel_fn}.spdx.json"
      [[ "$(ci::sha256_hex "stage/files/${rel_fn}.cdx.json")" = "${cdx_sha}" ]] ||
        ci::fail "Staged CycloneDX digest mismatch for ${rel_fn}.cdx.json"

      if [[ "${lineage_status}" = "verified-builder-manifest" ]]
      then
        jq -e \
          --arg formula "${formula}" \
          --arg pkg_version "${pkg_version}" \
          --arg brew_fn "${brew_fn}" \
          --arg rel_fn "${rel_fn}" \
          --arg bottle_sha "${bottle_sha}" \
          --arg spdx_sha "${spdx_sha}" \
          --arg cdx_sha "${cdx_sha}" \
          'any(.bottles[];
            .formula == $formula
            and .pkg_version == $pkg_version
            and .brew_filename == $brew_fn
            and .release_filename == $rel_fn
            and .bottle_sha256 == $bottle_sha
            and .spdx_sha256 == $spdx_sha
            and .cdx_sha256 == $cdx_sha
          )' "${RUNNER_TEMP}/verified-build-manifest.json" >/dev/null ||
          ci::fail "Entry ${rel_fn} does not match verified build-manifest.json from run ${TEST_RUN_ID}"
      fi

      if [[ "${MODE}" = "publish" ]]
      then
        if pub_rel="$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${release_tag}" 2>/dev/null)"
        then
          if printf '%s\n' "${pub_rel}" | jq -e --arg name "${rel_fn}" '.draft == false and any(.assets[]; .name == $name)' >/dev/null
          then
            ci::fail "Asset ${rel_fn} already exists on published release ${release_tag}; bump revision or rebuild instead of overwriting"
          fi
        fi
      fi

      cp -- "stage/files/${rel_fn}" "work/${rel_fn}"
      if [[ "${brew_fn}" != "${rel_fn}" ]]
      then
        cp -- "stage/files/${rel_fn}" "work/${brew_fn}"
      fi
      printf '%s  %s\n' "${bottle_sha}" "${brew_fn}" >>work/subject-checksums.txt
      printf '%s  %s\n' "${bottle_sha}" "${rel_fn}" >>work/subject-checksums.txt
      i=$((i + 1))
    done

    attested_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    jq -n \
      --slurpfile map stage/release-map.json \
      --arg mode "${MODE}" \
      --arg lineage_status "${lineage_status}" \
      --arg repo "${GITHUB_REPOSITORY}" \
      --arg signer "https://github.com/${GITHUB_REPOSITORY}/.github/workflows/sign-bottles.yml@refs/heads/main" \
      --arg signer_sha "${GITHUB_SHA}" \
      --arg builder_head "${builder_head_sha}" \
      --arg builder_wf "${builder_workflow}" \
      --arg builder_run "${builder_run_id}" \
      --arg builder_attempt "${builder_run_attempt}" \
      --arg prov_digest "${prov_artifact_digest}" \
      --arg attested_at "${attested_at}" \
      '{
        schema: "https://github.com/artagon/homebrew-aitools/bottle-lineage/v1",
        mode: $mode,
        lineage_status: $lineage_status,
        repository: $repo,
        signer_workflow: $signer,
        signer_commit_sha: $signer_sha,
        builder_head_sha: (if $builder_head == "" then null else $builder_head end),
        builder_workflow: (if $builder_wf == "" then null else $builder_wf end),
        builder_run_id: (if $builder_run == "" then null else $builder_run end),
        builder_run_attempt: (if $builder_attempt == "" then null else $builder_attempt end),
        provenance_artifact_digest: (if $prov_digest == "" then null else $prov_digest end),
        attested_at: $attested_at,
        bottles: $map[0].bottles
      }' >work/lineage.json
    ;;

  sign-and-verify)
    [[ -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP}" ]] || ci::fail "RUNNER_TEMP is not a directory"
    [[ -n "${SLSA_BUNDLE:-}" && -f "${SLSA_BUNDLE}" ]] || ci::fail "Missing SLSA_BUNDLE file"
    [[ -n "${LINEAGE_BUNDLE:-}" && -f "${LINEAGE_BUNDLE}" ]] || ci::fail "Missing LINEAGE_BUNDLE file"

    export TUF_ROOT="${RUNNER_TEMP}/cosign-tuf"
    mkdir -p -- "${TUF_ROOT}"

    gh_trusted_root="${RUNNER_TEMP}/trusted_root.jsonl"
    cosign_trusted_root="${RUNNER_TEMP}/sigstore-trusted-root.json"
    gh attestation trusted-root >"${gh_trusted_root}"
    jq -c -s '
      map(select(.mediaType == "application/vnd.dev.sigstore.trustedroot+json;version=0.1"))
      | (map(select(tostring | contains("sigstore.dev")))[0] // .[0])
    ' "${gh_trusted_root}" >"${cosign_trusted_root}"

    cert_id="https://github.com/${GITHUB_REPOSITORY}/.github/workflows/sign-bottles.yml@refs/heads/main"
    oidc_issuer="https://token.actions.githubusercontent.com"
    lineage_type="https://github.com/artagon/homebrew-aitools/bottle-lineage/v1"

    bottle_count="$(jq '.bottles | length' stage/release-map.json)"
    ci::require_uint "${bottle_count}" "bottle_count"
    i=0
    while [[ "${i}" -lt "${bottle_count}" ]]
    do
      entry="$(jq -c ".bottles[${i}]" stage/release-map.json)"
      formula="$(printf '%s\n' "${entry}" | jq -r .formula)"
      brew_fn="$(printf '%s\n' "${entry}" | jq -r .brew_filename)"
      rel_fn="$(printf '%s\n' "${entry}" | jq -r .release_filename)"
      bottle_sha="$(printf '%s\n' "${entry}" | jq -r .bottle_sha256)"
      spdx_sha="$(printf '%s\n' "${entry}" | jq -r .spdx_sha256)"
      cdx_sha="$(printf '%s\n' "${entry}" | jq -r .cdx_sha256)"

      ci::require_formula_name "${formula}" "formula"
      ci::require_safe_filename "${brew_fn}" "brew_filename"
      ci::require_safe_filename "${rel_fn}" "release_filename"
      ci::require_sha256 "${bottle_sha}" "bottle_sha256"
      ci::require_sha256 "${spdx_sha}" "spdx_sha256"
      ci::require_sha256 "${cdx_sha}" "cdx_sha256"

      cp -- "${SLSA_BUNDLE}" "out/${rel_fn}.intoto.jsonl"
      cp -- "${LINEAGE_BUNDLE}" "out/${rel_fn}.lineage.intoto.jsonl"
      cp -- "stage/files/${rel_fn}.spdx.json" "out/${rel_fn}.spdx.json"
      cp -- "stage/files/${rel_fn}.cdx.json" "out/${rel_fn}.cdx.json"
      printf '%s  %s\n' "${bottle_sha}" "${rel_fn}" >"out/${rel_fn}.sha256"

      jq --arg rel_fn "${rel_fn}" '
        .bottle = (.bottles[] | select(.release_filename == $rel_fn))
        | del(.bottles)
      ' work/lineage.json >"out/${rel_fn}.provenance.json"

      cosign sign-blob \
        --yes \
        --bundle "out/${rel_fn}.sigstore.json" \
        "work/${rel_fn}"

      cosign attest-blob \
        --yes \
        --type spdxjson \
        --predicate "out/${rel_fn}.spdx.json" \
        --bundle "out/${rel_fn}.spdx.sigstore.json" \
        "work/${rel_fn}"

      online_json="${RUNNER_TEMP}/verify-online-${i}.json"
      gh attestation verify "work/${rel_fn}" \
        --repo "${GITHUB_REPOSITORY}" \
        --cert-identity "${cert_id}" \
        --source-ref "refs/heads/main" \
        --deny-self-hosted-runners \
        --format json >"${online_json}"
      jq -e \
        --arg san "${cert_id}" \
        --arg brew_fn "${brew_fn}" \
        --arg rel_fn "${rel_fn}" \
        --arg sha "${bottle_sha}" \
        'any(.[];
          .verificationResult.signature.certificate.subjectAlternativeName == $san
          and (
            .verificationResult.statement.subject as $s
            | any($s[]; .name == $brew_fn and .digest.sha256 == $sha)
            and any($s[]; .name == $rel_fn and .digest.sha256 == $sha)
          )
        )' "${online_json}" >/dev/null || ci::fail "Online SLSA dual-subject check failed for ${formula}"

      offline_json="${RUNNER_TEMP}/verify-offline-${i}.json"
      gh attestation verify "work/${rel_fn}" \
        --repo "${GITHUB_REPOSITORY}" \
        --bundle "out/${rel_fn}.intoto.jsonl" \
        --custom-trusted-root "${gh_trusted_root}" \
        --cert-identity "${cert_id}" \
        --source-ref "refs/heads/main" \
        --deny-self-hosted-runners \
        --format json >"${offline_json}"
      jq -e \
        --arg san "${cert_id}" \
        --arg brew_fn "${brew_fn}" \
        --arg rel_fn "${rel_fn}" \
        --arg sha "${bottle_sha}" \
        'any(.[];
          .verificationResult.signature.certificate.subjectAlternativeName == $san
          and (
            .verificationResult.statement.subject as $s
            | any($s[]; .name == $brew_fn and .digest.sha256 == $sha)
            and any($s[]; .name == $rel_fn and .digest.sha256 == $sha)
          )
        )' "${offline_json}" >/dev/null || ci::fail "Offline SLSA bundle check failed for ${formula}"

      lineage_json="${RUNNER_TEMP}/verify-lineage-${i}.json"
      gh attestation verify "work/${rel_fn}" \
        --repo "${GITHUB_REPOSITORY}" \
        --bundle "out/${rel_fn}.lineage.intoto.jsonl" \
        --custom-trusted-root "${gh_trusted_root}" \
        --predicate-type "${lineage_type}" \
        --cert-identity "${cert_id}" \
        --source-ref "refs/heads/main" \
        --deny-self-hosted-runners \
        --format json >"${lineage_json}"
      jq -e \
        --arg rel_fn "${rel_fn}" \
        --arg sha "${bottle_sha}" \
        --arg spdx_sha "${spdx_sha}" \
        --arg cdx_sha "${cdx_sha}" \
        'any(.[];
          any(.verificationResult.statement.predicate.bottles[];
            .release_filename == $rel_fn
            and .bottle_sha256 == $sha
            and .spdx_sha256 == $spdx_sha
            and .cdx_sha256 == $cdx_sha
          )
        )' "${lineage_json}" >/dev/null || ci::fail "Signed bottle-lineage check failed for ${formula}"

      cosign verify-blob \
        --bundle "out/${rel_fn}.sigstore.json" \
        --trusted-root "${cosign_trusted_root}" \
        --certificate-identity "${cert_id}" \
        --certificate-oidc-issuer "${oidc_issuer}" \
        "work/${rel_fn}"

      cosign verify-blob-attestation \
        --bundle "out/${rel_fn}.spdx.sigstore.json" \
        --trusted-root "${cosign_trusted_root}" \
        --type spdxjson \
        --certificate-identity "${cert_id}" \
        --certificate-oidc-issuer "${oidc_issuer}" \
        "work/${rel_fn}"

      dsse_spdx="${RUNNER_TEMP}/dsse-spdx-${i}.json"
      detached_spdx="${RUNNER_TEMP}/detached-spdx-${i}.json"
      jq -r '.dsseEnvelope.payload' "out/${rel_fn}.spdx.sigstore.json" |
        base64 --decode |
        jq -S '.predicate' >"${dsse_spdx}"
      jq -S '.' "out/${rel_fn}.spdx.json" >"${detached_spdx}"
      cmp -s "${dsse_spdx}" "${detached_spdx}" ||
        ci::fail "Detached SPDX JSON does not match signed DSSE predicate for ${rel_fn}"
      i=$((i + 1))
    done
    ;;

  upload)
    [[ "${MODE:-}" = "publish" || "${MODE:-}" = "backfill" ]] ||
      ci::fail "MODE must be publish or backfill (got: ${MODE:-})"

    bottle_count="$(jq '.bottles | length' stage/release-map.json)"
    ci::require_uint "${bottle_count}" "bottle_count"
    i=0
    while [[ "${i}" -lt "${bottle_count}" ]]
    do
      entry="$(jq -c ".bottles[${i}]" stage/release-map.json)"
      release_tag="$(printf '%s\n' "${entry}" | jq -r .release_tag)"
      rel_fn="$(printf '%s\n' "${entry}" | jq -r .release_filename)"

      ci::require_safe_filename "${release_tag}" "release_tag"
      ci::require_safe_filename "${rel_fn}" "release_filename"

      sidecars=(
        "out/${rel_fn}.sha256"
        "out/${rel_fn}.spdx.json"
        "out/${rel_fn}.cdx.json"
        "out/${rel_fn}.intoto.jsonl"
        "out/${rel_fn}.lineage.intoto.jsonl"
        "out/${rel_fn}.sigstore.json"
        "out/${rel_fn}.spdx.sigstore.json"
        "out/${rel_fn}.provenance.json"
      )

      if [[ "${MODE}" = "publish" ]]
      then
        if ! gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${release_tag}" >/dev/null 2>&1
        then
          draft_id="$(
            gh api "repos/${GITHUB_REPOSITORY}/releases?per_page=100" |
              jq -r --arg tag "${release_tag}" '[.[] | select(.draft == true and .tag_name == $tag)] | first | .id // empty'
          )"
          if [[ -z "${draft_id}" ]]
          then
            gh release create "${release_tag}" \
              --repo "${GITHUB_REPOSITORY}" \
              --draft \
              --title "${release_tag}" \
              --notes "Homebrew bottle and cryptographic build provenance for ${release_tag}."
          fi
        fi
        gh release upload "${release_tag}" \
          --repo "${GITHUB_REPOSITORY}" \
          --clobber \
          -- \
          "work/${rel_fn}" \
          "${sidecars[@]}"
      else
        gh release upload "${release_tag}" \
          --repo "${GITHUB_REPOSITORY}" \
          --clobber \
          -- \
          "${sidecars[@]}"
      fi
      i=$((i + 1))
    done
    ;;

  *)
    ci::fail "Unknown subcommand: ${subcmd}"
    ;;
esac
