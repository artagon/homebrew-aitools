#!/usr/bin/env bash
# verify-provenance.sh — Verify Homebrew bottle digests, SLSA v1 provenance,
# signed bottle-lineage/v1 metadata, Sigstore cosign v3 bundles, and SBOMs for
# artagon/homebrew-aitools.
#
# Compatible with macOS /bin/bash 3.2 and Bash 5+ under `set -euo pipefail`.

# Helper functions return status codes to callers in `if` conditions and
# subshells; `brew style` enables SC2310/SC2312 optional checks globally.
# shellcheck disable=SC2310,SC2312

set -euo pipefail

readonly TAP_NAME="artagon/aitools"
readonly REPO_SLUG="${PROVENANCE_REPO_SLUG:-artagon/homebrew-aitools}"
readonly CERT_IDENTITY="${PROVENANCE_CERT_IDENTITY:-https://github.com/artagon/homebrew-aitools/.github/workflows/sign-bottles.yml@refs/heads/main}"
readonly SOURCE_REF="${PROVENANCE_SOURCE_REF:-refs/heads/main}"
readonly OIDC_ISSUER="${PROVENANCE_OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
readonly LINEAGE_PREDICATE_TYPE="https://github.com/artagon/homebrew-aitools/bottle-lineage/v1"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="${PROVENANCE_REPO_ROOT:-$(cd "${script_dir}/.." && pwd -P)}"
formula_dir="${repo_root}/Formula"

scratch_dir=""
# Invoked indirectly via `trap cleanup EXIT`.
# shellcheck disable=SC2329
cleanup() {
  local rc=$?
  if [[ -n "${scratch_dir}" ]] && [[ -d "${scratch_dir}" ]]
  then
    rm -rf "${scratch_dir}"
  fi
  return "${rc}"
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [formula...]

Verify cryptographic build provenance, Sigstore bundles, and SBOMs for bottles
in ${TAP_NAME}.

Options:
  --all                   Verify all bottled formulae in Formula/*.rb (default)
  --file PATH             Verify a local bottle tarball (single formula only)
  --bundle-dir DIR        Read detached sidecar bundles and SBOMs from DIR
  --save-bundles DIR      Save downloaded sidecars and trusted_root.jsonl to DIR
  --offline               Verify strictly offline (requires --bundle-dir and trusted root)
  --trusted-root PATH     Path to trusted_root.jsonl from 'gh attestation trusted-root'
  --require-cosign        Fail instead of skipping when cosign is not installed
  --homebrew              Also run isolated 'brew verify' for each formula
  --bottle-tag TAG        Bottle tag to verify (default: arm64_tahoe)
  --allow-file-root-url   Allow file:/// bottle root_url for local test fixtures
  --parse-only            Parse and validate Formula/*.rb bottle metadata only
  --json                  Emit machine-readable JSON summary on stdout
  -h, --help              Show this help message

Examples:
  $(basename "$0") ripwire
  $(basename "$0") --all --require-cosign --homebrew
  $(basename "$0") --save-bundles ./bundles ripwire
  $(basename "$0") --offline --bundle-dir ./bundles --trusted-root ./bundles/trusted_root.jsonl ripwire
EOF
}

usage_error() {
  printf 'verify-provenance: %s\n' "$*" >&2
  exit 2
}

log_info() {
  if [[ "${json_output}" -eq 0 ]]
  then
    printf '%s\n' "$*" >&2
  fi
}

sha256_file() {
  local target="$1"
  if command -v shasum >/dev/null 2>&1
  then
    shasum -a 256 "${target}" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1
  then
    sha256sum "${target}" | awk '{ print $1 }'
  else
    return 1
  fi
}

# Extract upstream version from a literal formula URL.
extract_version_from_url() {
  local formula="$1"
  local raw_url="$2"
  local dl_re='releases/download/([^/]+)/'
  local archive_re='archive/(refs/tags/)?([^/]+)\.(tar\.gz|tar\.xz|tgz|zip)$'
  local tag_part=""

  if [[ "${raw_url}" =~ ${dl_re} ]]
  then
    tag_part="${BASH_REMATCH[1]}"
  elif [[ "${raw_url}" =~ ${archive_re} ]]
  then
    tag_part="${BASH_REMATCH[2]}"
  fi

  if [[ -n "${tag_part}" ]]
  then
    if [[ "${tag_part}" == "${formula}-"* ]]
    then
      tag_part="${tag_part#"${formula}-"}"
    fi
    if [[ "${tag_part}" =~ ^[vV]([0-9].*)$ ]]
    then
      tag_part="${BASH_REMATCH[1]}"
    fi
    printf '%s\n' "${tag_part}"
    return 0
  fi

  return 1
}

# Parse Formula/<name>.rb deterministically without executing Ruby.
# Populates global parsed_* variables for the current formula.
parsed_version=""
parsed_revision="0"
parsed_pkg_version=""
parsed_root_url=""
parsed_rebuild="0"
parsed_bottle_sha256=""
parsed_brew_filename=""
parsed_release_filename=""
parsed_release_tag=""
parsed_error=""

parse_formula_metadata() {
  local formula="$1"
  local tag="$2"
  local rb_file="${formula_dir}/${formula}.rb"

  parsed_version=""
  parsed_revision="0"
  parsed_pkg_version=""
  parsed_root_url=""
  parsed_rebuild="0"
  parsed_bottle_sha256=""
  parsed_brew_filename=""
  parsed_release_filename=""
  parsed_release_tag=""
  parsed_error=""

  if [[ ! -f "${rb_file}" ]]
  then
    parsed_error="Formula file not found: ${rb_file}"
    return 1
  fi

  local in_livecheck=0 livecheck_indent=""
  local in_bottle=0 bottle_indent=""
  local in_resource=0 resource_indent=""
  local explicit_version="" primary_url="" line=""

  local stop_re='^  (def (install|caveats|post_install)|test do)$|^__END__$'
  local livecheck_start_re='^([[:space:]]*)livecheck do$'
  local bottle_start_re='^([[:space:]]*)bottle do$'
  local resource_start_re='^([[:space:]]*)resource "[^"]+" do$'
  local version_line_re='^  version "([^"]+)"$'
  local revision_line_re='^  revision ([0-9]+)$'
  local url_line_re='^[[:space:]]*url "([^"]+)"$'
  local root_url_re='^[[:space:]]*root_url "([^"]+)"$'
  local rebuild_re='^[[:space:]]*rebuild ([0-9]+)$'
  local tag_sha_re="${tag}: \"([0-9a-f]{64})\""

  while IFS= read -r line || [[ -n "${line}" ]]
  do
    if [[ "${line}" =~ ${stop_re} ]]
    then
      break
    fi

    if [[ "${in_livecheck}" -eq 1 ]]
    then
      if [[ "${line}" == "${livecheck_indent}end" ]]
      then
        in_livecheck=0
        livecheck_indent=""
      fi
      continue
    fi

    if [[ "${in_resource}" -eq 1 ]]
    then
      if [[ "${line}" == "${resource_indent}end" ]]
      then
        in_resource=0
        resource_indent=""
      fi
      continue
    fi

    if [[ "${in_bottle}" -eq 1 ]]
    then
      if [[ "${line}" == "${bottle_indent}end" ]]
      then
        in_bottle=0
        bottle_indent=""
        continue
      fi
      if [[ "${line}" =~ ${root_url_re} ]]
      then
        parsed_root_url="${BASH_REMATCH[1]}"
      elif [[ "${line}" =~ ${rebuild_re} ]]
      then
        parsed_rebuild="${BASH_REMATCH[1]}"
      elif [[ "${line}" =~ ^[[:space:]]*sha256[[:space:]] ]] && [[ "${line}" =~ ${tag_sha_re} ]]
      then
        parsed_bottle_sha256="${BASH_REMATCH[1]}"
      fi
      continue
    fi

    if [[ "${line}" =~ ${livecheck_start_re} ]]
    then
      in_livecheck=1
      livecheck_indent="${BASH_REMATCH[1]}"
      continue
    fi

    if [[ "${line}" =~ ${resource_start_re} ]]
    then
      in_resource=1
      resource_indent="${BASH_REMATCH[1]}"
      continue
    fi

    if [[ "${line}" =~ ${bottle_start_re} ]]
    then
      in_bottle=1
      bottle_indent="${BASH_REMATCH[1]}"
      continue
    fi

    if [[ "${line}" =~ ${version_line_re} ]]
    then
      explicit_version="${BASH_REMATCH[1]}"
    elif [[ "${line}" =~ ${revision_line_re} ]]
    then
      parsed_revision="${BASH_REMATCH[1]}"
    elif [[ -z "${primary_url}" ]] && [[ "${line}" =~ ${url_line_re} ]]
    then
      primary_url="${BASH_REMATCH[1]}"
    fi
  done <"${rb_file}"

  if [[ -n "${explicit_version}" ]]
  then
    parsed_version="${explicit_version}"
  elif [[ -n "${primary_url}" ]]
  then
    parsed_version="$(extract_version_from_url "${formula}" "${primary_url}" || true)"
  fi

  if [[ -z "${parsed_version}" ]]
  then
    parsed_error="Could not determine upstream version from ${rb_file}"
    return 1
  fi

  if [[ "${parsed_revision}" -gt 0 ]]
  then
    parsed_pkg_version="${parsed_version}_${parsed_revision}"
  else
    parsed_pkg_version="${parsed_version}"
  fi

  parsed_release_tag="${formula}-${parsed_pkg_version}"

  local rebuild_suffix=""
  if [[ "${parsed_rebuild}" -gt 0 ]]
  then
    rebuild_suffix=".${parsed_rebuild}"
  fi

  local extname=".${tag}.bottle${rebuild_suffix}.tar.gz"
  parsed_brew_filename="${formula}--${parsed_pkg_version}${extname}"
  local raw_release_name="${formula}-${parsed_pkg_version}${extname}"
  parsed_release_filename="$(jq -rn --arg s "${raw_release_name}" '$s | @uri')"

  if [[ -z "${parsed_bottle_sha256}" ]]
  then
    parsed_error="No ${tag} bottle sha256 found in ${rb_file}"
    return 1
  fi

  if [[ -z "${parsed_root_url}" ]]
  then
    parsed_error="No bottle root_url found in ${rb_file}"
    return 1
  fi

  local expected_https_root="https://github.com/${REPO_SLUG}/releases/download/${parsed_release_tag}"
  if [[ "${parsed_root_url}" == "${expected_https_root}" ]]
  then
    return 0
  fi

  if [[ "${allow_file_root_url}" -eq 1 ]] &&
     [[ "${parsed_root_url}" =~ ^file:///[^[:space:]]+$ ]] &&
     [[ "${parsed_root_url}" != *".."* ]] &&
     [[ "${parsed_root_url}" == *"/${parsed_release_tag}" ]]
  then
    return 0
  fi

  parsed_error="Unexpected or stale bottle root_url '${parsed_root_url}' (expected '${expected_https_root}')"
  return 1
}

fetch_asset() {
  local base_url="$1"
  local asset_name="$2"
  local dest_path="$3"

  if [[ -n "${bundle_dir}" ]]
  then
    if [[ -f "${bundle_dir}/${asset_name}" ]]
    then
      cp "${bundle_dir}/${asset_name}" "${dest_path}"
      return 0
    fi
    return 1
  fi

  if [[ "${offline_mode}" -eq 1 ]]
  then
    return 1
  fi

  curl --disable --fail --location --silent --show-error --retry 3 \
    --output "${dest_path}" \
    "${base_url}/${asset_name}"
}

prepare_cosign_trusted_root() {
  local jsonl_path="$1"
  local out_path="$2"

  jq -c -s '
    map(select(.mediaType == "application/vnd.dev.sigstore.trustedroot+json;version=0.1"))
    | (map(select(tostring | contains("sigstore.dev")))[0] // .[0] // empty)
  ' "${jsonl_path}" >"${out_path}"

  [[ -s "${out_path}" ]]
}

# Verify one formula and append a structured JSON result line to $2.
verify_one_formula() {
  local formula="$1"
  local results_file="$2"
  local f_work="${scratch_dir}/formula-${formula}"
  mkdir -p "${f_work}/sidecars"

  local st_metadata="pending"
  local st_sha256="skipped"
  local st_sha256_sidecar="skipped"
  local st_slsa="skipped"
  local st_lineage="skipped"
  local st_cosign_blob="skipped"
  local st_cosign_spdx="skipped"
  local st_spdx="skipped"
  local st_cdx="skipped"
  local st_homebrew="skipped"
  local spdx_pkg_count=0
  local cdx_comp_count=0
  local actual_bottle_sha=""
  local err_msg=""

  emit_result() {
    local ok_flag="$1"
    jq -c -n \
      --arg formula "${formula}" \
      --argjson ok "${ok_flag}" \
      --arg version "${parsed_version}" \
      --arg pkg_version "${parsed_pkg_version}" \
      --arg release_tag "${parsed_release_tag}" \
      --arg root_url "${parsed_root_url}" \
      --argjson rebuild "${parsed_rebuild}" \
      --arg bottle_tag "${bottle_tag}" \
      --arg brew_filename "${parsed_brew_filename}" \
      --arg release_filename "${parsed_release_filename}" \
      --arg expected_sha256 "${parsed_bottle_sha256}" \
      --arg actual_sha256 "${actual_bottle_sha}" \
      --arg st_metadata "${st_metadata}" \
      --arg st_sha256 "${st_sha256}" \
      --arg st_sha256_sidecar "${st_sha256_sidecar}" \
      --arg st_slsa "${st_slsa}" \
      --arg st_lineage "${st_lineage}" \
      --arg st_cosign_blob "${st_cosign_blob}" \
      --arg st_cosign_spdx "${st_cosign_spdx}" \
      --arg st_spdx "${st_spdx}" \
      --arg st_cdx "${st_cdx}" \
      --arg st_homebrew "${st_homebrew}" \
      --argjson spdx_packages "${spdx_pkg_count}" \
      --argjson cdx_components "${cdx_comp_count}" \
      --arg error "${err_msg}" \
      '{
        formula: $formula,
        ok: $ok,
        version: $version,
        pkg_version: $pkg_version,
        release_tag: $release_tag,
        root_url: $root_url,
        rebuild: $rebuild,
        bottle_tag: $bottle_tag,
        brew_filename: $brew_filename,
        release_filename: $release_filename,
        expected_sha256: $expected_sha256,
        actual_sha256: $actual_sha256,
        spdx_packages: $spdx_packages,
        cyclonedx_components: $cdx_components,
        checks: {
          formula_metadata: $st_metadata,
          bottle_sha256: $st_sha256,
          sha256_sidecar: $st_sha256_sidecar,
          slsa_attestation: $st_slsa,
          lineage_attestation: $st_lineage,
          cosign_blob: $st_cosign_blob,
          cosign_spdx: $st_cosign_spdx,
          spdx_sbom: $st_spdx,
          cyclonedx_sbom: $st_cdx,
          homebrew_verify: $st_homebrew
        },
        error: (if $error == "" then null else $error end)
      }' >>"${results_file}"
  }

  log_info "==> Checking ${TAP_NAME}/${formula} (${bottle_tag})..."

  if ! parse_formula_metadata "${formula}" "${bottle_tag}"
  then
    st_metadata="failed"
    err_msg="${parsed_error}"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi
  st_metadata="passed"

  if [[ "${parse_only}" -eq 1 ]]
  then
    log_info "  [OK] Metadata parsed: ${parsed_brew_filename} (${parsed_bottle_sha256})"
    emit_result true
    return 0
  fi

  # 1. Obtain bottle tarball and verify SHA-256 against Formula/<name>.rb.
  local bottle_path="${f_work}/${parsed_release_filename}"
  if [[ -n "${local_bottle_file}" ]]
  then
    if [[ ! -f "${local_bottle_file}" ]]
    then
      st_sha256="failed"
      err_msg="Bottle file not found: ${local_bottle_file}"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    cp "${local_bottle_file}" "${bottle_path}"
  elif [[ "${offline_mode}" -eq 1 ]]
  then
    if [[ -f "${bundle_dir}/${parsed_release_filename}" ]]
    then
      cp "${bundle_dir}/${parsed_release_filename}" "${bottle_path}"
    elif [[ -f "${bundle_dir}/${parsed_brew_filename}" ]]
    then
      cp "${bundle_dir}/${parsed_brew_filename}" "${bottle_path}"
    else
      st_sha256="failed"
      err_msg="Offline mode requires --file or ${parsed_release_filename} in --bundle-dir"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
  else
    if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}" "${bottle_path}"
    then
      st_sha256="failed"
      err_msg="Failed to download bottle ${parsed_root_url}/${parsed_release_filename}"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
  fi

  actual_bottle_sha="$(sha256_file "${bottle_path}" || true)"
  if [[ "${actual_bottle_sha}" != "${parsed_bottle_sha256}" ]]
  then
    st_sha256="failed"
    err_msg="Bottle SHA-256 mismatch: expected ${parsed_bottle_sha256}, got ${actual_bottle_sha:-missing}"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi
  st_sha256="passed"
  log_info "  [OK] Bottle SHA-256 matches Formula/${formula}.rb (${actual_bottle_sha})"

  # Optional .sha256 sidecar verification (required when present or online).
  local sha_sidecar="${f_work}/sidecars/${parsed_release_filename}.sha256"
  if fetch_asset "${parsed_root_url}" "${parsed_release_filename}.sha256" "${sha_sidecar}" 2>/dev/null
  then
    local expected_line="${parsed_bottle_sha256}  ${parsed_release_filename}"
    local actual_line=""
    IFS= read -r actual_line <"${sha_sidecar}" || true
    actual_line="${actual_line%$'\r'}"
    if [[ "${actual_line}" != "${expected_line}" ]]
    then
      st_sha256_sidecar="failed"
      err_msg="Sidecar .sha256 mismatch: expected '${expected_line}', got '${actual_line}'"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    st_sha256_sidecar="passed"
  fi

  # 2. Fetch SBOM sidecars and verify SLSA v1 provenance.
  local spdx_path="${f_work}/sidecars/${parsed_release_filename}.spdx.json"
  local cdx_path="${f_work}/sidecars/${parsed_release_filename}.cdx.json"
  if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}.spdx.json" "${spdx_path}"
  then
    st_spdx="failed"
    err_msg="Missing SPDX SBOM sidecar: ${parsed_release_filename}.spdx.json"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi
  if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}.cdx.json" "${cdx_path}"
  then
    st_cdx="failed"
    err_msg="Missing CycloneDX SBOM sidecar: ${parsed_release_filename}.cdx.json"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi

  local slsa_out="${f_work}/slsa-verify.json"
  local gh_slsa_args=(
    attestation verify "${bottle_path}"
    --repo "${REPO_SLUG}"
    --cert-identity "${CERT_IDENTITY}"
    --source-ref "${SOURCE_REF}"
    --deny-self-hosted-runners
    --format json
  )

  local slsa_bundle_path="${f_work}/sidecars/${parsed_release_filename}.intoto.jsonl"
  if [[ -n "${bundle_dir}" ]]
  then
    if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}.intoto.jsonl" "${slsa_bundle_path}"
    then
      st_slsa="failed"
      err_msg="Missing SLSA bundle in --bundle-dir: ${parsed_release_filename}.intoto.jsonl"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    gh_slsa_args+=(--bundle "${slsa_bundle_path}")
  elif [[ -n "${save_bundles_dir}" ]]
  then
    if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}.intoto.jsonl" "${slsa_bundle_path}"
    then
      st_slsa="failed"
      err_msg="Failed to download SLSA bundle: ${parsed_release_filename}.intoto.jsonl"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    gh_slsa_args+=(--bundle "${slsa_bundle_path}")
  fi

  if [[ -n "${effective_trusted_root}" ]]
  then
    gh_slsa_args+=(--custom-trusted-root "${effective_trusted_root}")
  fi

  if ! gh "${gh_slsa_args[@]}" >"${slsa_out}" 2>"${f_work}/gh-slsa.err"
  then
    st_slsa="failed"
    err_msg="gh attestation verify (SLSA v1) failed for ${formula}"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi

  # Atomic dual-subject check: BOTH `--` (Homebrew cache) and `-` (GitHub Release)
  # subjects must match actual_bottle_sha inside the SAME verified statement.
  if ! jq -e \
     --arg san "${CERT_IDENTITY}" \
     --arg brew_fn "${parsed_brew_filename}" \
     --arg rel_fn "${parsed_release_filename}" \
     --arg sha "${actual_bottle_sha}" \
        'type == "array" and any(.[];
        .verificationResult.signature.certificate.subjectAlternativeName == $san
        and .verificationResult.statement.predicateType == "https://slsa.dev/provenance/v1"
     and (
     .verificationResult.statement.subject as $s
        | ($s | type == "array")
     and any($s[]; .name == $brew_fn and .digest.sha256 == $sha)
     and any($s[]; .name == $rel_fn and .digest.sha256 == $sha)
     )
     )' "${slsa_out}" >/dev/null 2>&1
  then
    st_slsa="failed"
    err_msg="SLSA attestation failed atomic dual-subject (${parsed_brew_filename} + ${parsed_release_filename}) check"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi
  st_slsa="passed"
  log_info "  [OK] SLSA v1 provenance verified (ref-bound SAN + dual subject)"

  # 3. Verify signed bottle-lineage/v1 attestation authenticating SPDX + CycloneDX SHA-256.
  local actual_spdx_sha=""
  local actual_cdx_sha=""
  actual_spdx_sha="$(sha256_file "${spdx_path}" || true)"
  actual_cdx_sha="$(sha256_file "${cdx_path}" || true)"

  local lineage_out="${f_work}/lineage-verify.json"
  local gh_lineage_args=(
    attestation verify "${bottle_path}"
    --repo "${REPO_SLUG}"
    --predicate-type "${LINEAGE_PREDICATE_TYPE}"
    --cert-identity "${CERT_IDENTITY}"
    --source-ref "${SOURCE_REF}"
    --deny-self-hosted-runners
    --format json
  )

  local lineage_bundle_path="${f_work}/sidecars/${parsed_release_filename}.lineage.intoto.jsonl"
  if [[ -n "${bundle_dir}" ]]
  then
    if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}.lineage.intoto.jsonl" "${lineage_bundle_path}"
    then
      st_lineage="failed"
      err_msg="Missing lineage bundle in --bundle-dir: ${parsed_release_filename}.lineage.intoto.jsonl"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    gh_lineage_args+=(--bundle "${lineage_bundle_path}")
  elif [[ -n "${save_bundles_dir}" ]]
  then
    if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}.lineage.intoto.jsonl" "${lineage_bundle_path}"
    then
      st_lineage="failed"
      err_msg="Failed to download lineage bundle: ${parsed_release_filename}.lineage.intoto.jsonl"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    gh_lineage_args+=(--bundle "${lineage_bundle_path}")
  fi

  if [[ -n "${effective_trusted_root}" ]]
  then
    gh_lineage_args+=(--custom-trusted-root "${effective_trusted_root}")
  fi

  if ! gh "${gh_lineage_args[@]}" >"${lineage_out}" 2>"${f_work}/gh-lineage.err"
  then
    st_lineage="failed"
    err_msg="gh attestation verify (bottle-lineage/v1) failed for ${formula}"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi

  if ! jq -e \
     --arg san "${CERT_IDENTITY}" \
     --arg formula "${formula}" \
     --arg brew_fn "${parsed_brew_filename}" \
     --arg rel_fn "${parsed_release_filename}" \
     --arg sha "${actual_bottle_sha}" \
     --arg spdx_sha "${actual_spdx_sha}" \
     --arg cdx_sha "${actual_cdx_sha}" \
        'type == "array" and any(.[];
        .verificationResult.signature.certificate.subjectAlternativeName == $san
        and .verificationResult.statement.predicateType == "https://github.com/artagon/homebrew-aitools/bottle-lineage/v1"
     and (
     .verificationResult.statement.subject as $s
        | ($s | type == "array")
     and any($s[]; .name == $brew_fn and .digest.sha256 == $sha)
     and any($s[]; .name == $rel_fn and .digest.sha256 == $sha)
     )
     and any(.verificationResult.statement.predicate.bottles[];
        .formula == $formula
        and .release_filename == $rel_fn
        and .bottle_sha256 == $sha
        and .spdx_sha256 == $spdx_sha
        and .cdx_sha256 == $cdx_sha
     )
     )' "${lineage_out}" >/dev/null 2>&1
  then
    st_lineage="failed"
    err_msg="Signed bottle-lineage/v1 predicate or SBOM digest mismatch for ${formula}"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi
  st_lineage="passed"
  log_info "  [OK] Signed bottle-lineage/v1 verified (SPDX + CycloneDX digests authenticated)"

  # 4. Verify Sigstore cosign v3 blob signature and SPDX DSSE bundle.
  local sig_bundle="${f_work}/sidecars/${parsed_release_filename}.sigstore.json"
  local spdx_sig_bundle="${f_work}/sidecars/${parsed_release_filename}.spdx.sigstore.json"

  if command -v cosign >/dev/null 2>&1
  then
    if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}.sigstore.json" "${sig_bundle}"
    then
      st_cosign_blob="failed"
      err_msg="Missing Sigstore blob bundle: ${parsed_release_filename}.sigstore.json"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    if ! fetch_asset "${parsed_root_url}" "${parsed_release_filename}.spdx.sigstore.json" "${spdx_sig_bundle}"
    then
      st_cosign_spdx="failed"
      err_msg="Missing Sigstore SPDX bundle: ${parsed_release_filename}.spdx.sigstore.json"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi

    local cosign_blob_args=(
      verify-blob
      --bundle "${sig_bundle}"
      --certificate-identity "${CERT_IDENTITY}"
      --certificate-oidc-issuer "${OIDC_ISSUER}"
    )
    local cosign_spdx_args=(
      verify-blob-attestation
      --bundle "${spdx_sig_bundle}"
      --type spdxjson
      --certificate-identity "${CERT_IDENTITY}"
      --certificate-oidc-issuer "${OIDC_ISSUER}"
    )
    if [[ -n "${cosign_trusted_root}" ]]
    then
      cosign_blob_args+=(--trusted-root "${cosign_trusted_root}")
      cosign_spdx_args+=(--trusted-root "${cosign_trusted_root}")
    fi
    cosign_blob_args+=("${bottle_path}")
    cosign_spdx_args+=("${bottle_path}")

    if ! TUF_ROOT="${scratch_dir}/cosign-tuf" cosign "${cosign_blob_args[@]}" >"${f_work}/cosign-blob.out" 2>&1
    then
      st_cosign_blob="failed"
      err_msg="cosign verify-blob failed for ${parsed_release_filename}"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    st_cosign_blob="passed"

    if ! TUF_ROOT="${scratch_dir}/cosign-tuf" cosign "${cosign_spdx_args[@]}" >"${f_work}/cosign-spdx.out" 2>&1
    then
      st_cosign_spdx="failed"
      err_msg="cosign verify-blob-attestation (spdxjson) failed for ${parsed_release_filename}"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi

    # Authenticate detached .spdx.json directly against signed DSSE predicate.
    local dsse_spdx="${f_work}/dsse-predicate-spdx.json"
    local detached_spdx="${f_work}/detached-spdx.json"
    if ! jq -S '.dsseEnvelope.payload | @base64d | fromjson | .predicate' "${spdx_sig_bundle}" >"${dsse_spdx}" 2>/dev/null ||
       ! jq -S '.' "${spdx_path}" >"${detached_spdx}" 2>/dev/null ||
       ! cmp -s "${dsse_spdx}" "${detached_spdx}"
    then
      st_cosign_spdx="failed"
      err_msg="Detached SPDX JSON does not match signed cosign DSSE predicate for ${parsed_release_filename}"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    st_cosign_spdx="passed"
    log_info "  [OK] Sigstore cosign v3 blob + SPDX DSSE bundles verified"
  elif [[ "${require_cosign}" -eq 1 ]]
  then
    st_cosign_blob="failed"
    st_cosign_spdx="failed"
    err_msg="cosign is required (--require-cosign) but not found on PATH"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  else
    log_info "  [SKIP] cosign not installed; skipped Sigstore v3 bundle checks"
    if [[ -n "${save_bundles_dir}" ]]
    then
      fetch_asset "${parsed_root_url}" "${parsed_release_filename}.sigstore.json" "${sig_bundle}" || true
      fetch_asset "${parsed_root_url}" "${parsed_release_filename}.spdx.sigstore.json" "${spdx_sig_bundle}" || true
    fi
  fi

  # 5. Validate SPDX 2.3 and CycloneDX JSON schemas and package counts.
  if ! jq -e '.spdxVersion == "SPDX-2.3" and (.name | type == "string" and length > 0) and (.packages | type == "array")' \
     "${spdx_path}" >/dev/null 2>&1
  then
    st_spdx="failed"
    err_msg="Invalid SPDX 2.3 JSON document: ${parsed_release_filename}.spdx.json"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi
  spdx_pkg_count="$(jq '.packages | length' "${spdx_path}")"
  st_spdx="passed"

  if ! jq -e '.bomFormat == "CycloneDX" and (.specVersion | type == "string" and length > 0)' \
     "${cdx_path}" >/dev/null 2>&1
  then
    st_cdx="failed"
    err_msg="Invalid CycloneDX JSON document: ${parsed_release_filename}.cdx.json"
    log_info "  [FAIL] ${err_msg}"
    emit_result false
    return 1
  fi
  cdx_comp_count="$(jq '(.components // []) | length' "${cdx_path}")"
  st_cdx="passed"
  log_info "  [OK] SBOMs valid (SPDX-2.3: ${spdx_pkg_count} packages, CycloneDX: ${cdx_comp_count} components)"

  # 6. Optional isolated Homebrew `brew verify` check.
  if [[ "${homebrew_mode}" -eq 1 ]]
  then
    if ! command -v brew >/dev/null 2>&1
    then
      st_homebrew="failed"
      err_msg="brew is required (--homebrew) but not found on PATH"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi

    local tap_repo=""
    tap_repo="$(brew --repository "${TAP_NAME}" 2>/dev/null || true)"
    if [[ -n "${tap_repo}" ]] && [[ -f "${tap_repo}/Formula/${formula}.rb" ]]
    then
      local tap_rb_sha=""
      local local_rb_sha=""
      tap_rb_sha="$(sha256_file "${tap_repo}/Formula/${formula}.rb" || true)"
      local_rb_sha="$(sha256_file "${formula_dir}/${formula}.rb" || true)"
      if [[ "${tap_rb_sha}" != "${local_rb_sha}" ]]
      then
        st_homebrew="failed"
        err_msg="Installed tap ${tap_repo}/Formula/${formula}.rb differs from checkout Formula/${formula}.rb"
        log_info "  [FAIL] ${err_msg}"
        emit_result false
        return 1
      fi
    fi

    local brew_out="${f_work}/brew-verify.json"
    if ! (
       export USER="${USER:-$(id -un)}"
       if [[ -z "${GH_CONFIG_DIR:-}" ]] && [[ -d "${HOME}/.config/gh" ]]
    then
        export GH_CONFIG_DIR="${HOME}/.config/gh"
      fi
      export GH_STATE_DIR="${f_work}/gh-state"
      export XDG_CONFIG_HOME="${f_work}/brew-xdg"
      export HOMEBREW_CACHE="${f_work}/brew-cache"
      export HOMEBREW_LOGS="${f_work}/brew-logs"
      export HOMEBREW_TEMP="${f_work}/brew-temp"
      mkdir -p "${GH_STATE_DIR}" "${XDG_CONFIG_HOME}" "${HOMEBREW_CACHE}" "${HOMEBREW_LOGS}" "${HOMEBREW_TEMP}"
      brew trust --tap "${TAP_NAME}" >/dev/null 2>&1
      brew verify \
        "--bottle-tag=${bottle_tag}" \
        --force \
        --json \
        "${TAP_NAME}/${formula}" >"${brew_out}"
    ) 2>"${f_work}/brew-verify.err"; then
      st_homebrew="failed"
      err_msg="brew verify failed for ${TAP_NAME}/${formula}"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi

    if ! jq -e 'type == "array" and length == 1' "${brew_out}" >/dev/null 2>&1
    then
      st_homebrew="failed"
      err_msg="brew verify did not return 1 verified bottle result for ${TAP_NAME}/${formula}"
      log_info "  [FAIL] ${err_msg}"
      emit_result false
      return 1
    fi
    st_homebrew="passed"
    log_info "  [OK] Isolated Homebrew 'brew verify' passed"
  fi

  # Persist verified bundles when --save-bundles is requested.
  if [[ -n "${save_bundles_dir}" ]]
  then
    mkdir -p "${save_bundles_dir}"
    cp "${bottle_path}" "${save_bundles_dir}/${parsed_release_filename}"
    local asset_file=""
    for asset_file in "${f_work}/sidecars"/*
    do
      if [[ -f "${asset_file}" ]]
      then
        cp "${asset_file}" "${save_bundles_dir}/"
      fi
    done
  fi

  emit_result true
  return 0
}

# ── Parse CLI Arguments ──────────────────────────────────────────────────────
want_all=0
local_bottle_file=""
bundle_dir=""
save_bundles_dir=""
offline_mode=0
trusted_root_arg=""
require_cosign=0
homebrew_mode=0
bottle_tag="arm64_tahoe"
allow_file_root_url=0
parse_only=0
json_output=0
formula_args=("__placeholder__")
formula_count=0

while [[ $# -gt 0 ]]
do
  case "$1" in
    --all)
      want_all=1
      ;;
    --file)
      [[ $# -ge 2 ]] || usage_error "--file requires a PATH argument"
      local_bottle_file="$2"
      shift
      ;;
    --bundle-dir)
      [[ $# -ge 2 ]] || usage_error "--bundle-dir requires a DIR argument"
      bundle_dir="$2"
      shift
      ;;
    --save-bundles)
      [[ $# -ge 2 ]] || usage_error "--save-bundles requires a DIR argument"
      save_bundles_dir="$2"
      shift
      ;;
    --offline)
      offline_mode=1
      ;;
    --trusted-root)
      [[ $# -ge 2 ]] || usage_error "--trusted-root requires a PATH argument"
      trusted_root_arg="$2"
      shift
      ;;
    --require-cosign)
      require_cosign=1
      ;;
    --homebrew)
      homebrew_mode=1
      ;;
    --bottle-tag)
      [[ $# -ge 2 ]] || usage_error "--bottle-tag requires a TAG argument"
      bottle_tag="$2"
      shift
      ;;
    --allow-file-root-url)
      allow_file_root_url=1
      ;;
    --parse-only)
      parse_only=1
      ;;
    --json)
      json_output=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --*)
      usage_error "Unknown option: $1"
      ;;
    *)
      if [[ "${formula_count}" -eq 0 ]]
      then
        formula_args=("$1")
      else
        formula_args+=("$1")
      fi
      formula_count=$((formula_count + 1))
      ;;
  esac
  shift
done

# Validate option combinations before creating scratch state.
if [[ ! "${bottle_tag}" =~ ^[a-z0-9_]+$ ]]
then
  usage_error "Invalid --bottle-tag: ${bottle_tag}"
fi

if [[ "${offline_mode}" -eq 1 ]]
then
  [[ -n "${bundle_dir}" ]] || usage_error "--offline requires --bundle-dir DIR"
  [[ -z "${save_bundles_dir}" ]] || usage_error "--offline cannot be combined with --save-bundles"
  [[ "${homebrew_mode}" -eq 0 ]] || usage_error "--offline cannot be combined with --homebrew"
fi

if [[ -n "${bundle_dir}" ]] && [[ ! -d "${bundle_dir}" ]]
then
  usage_error "--bundle-dir does not exist: ${bundle_dir}"
fi

effective_trusted_root=""
if [[ -n "${trusted_root_arg}" ]]
then
  effective_trusted_root="${trusted_root_arg}"
elif [[ -n "${PROVENANCE_TRUSTED_ROOT:-}" ]]
then
  effective_trusted_root="${PROVENANCE_TRUSTED_ROOT}"
elif [[ "${offline_mode}" -eq 1 ]] && [[ -n "${bundle_dir}" ]] && [[ -f "${bundle_dir}/trusted_root.jsonl" ]]
then
  effective_trusted_root="${bundle_dir}/trusted_root.jsonl"
fi

if [[ "${offline_mode}" -eq 1 ]] && [[ -z "${effective_trusted_root}" ]]
then
  usage_error "--offline requires --trusted-root PATH (or trusted_root.jsonl in --bundle-dir)"
fi

if [[ -n "${effective_trusted_root}" ]] && [[ ! -f "${effective_trusted_root}" ]]
then
  usage_error "Trusted root file not found: ${effective_trusted_root}"
fi

if ! command -v jq >/dev/null 2>&1
then
  usage_error "jq is required on PATH"
fi

if [[ "${parse_only}" -eq 0 ]]
then
  if ! command -v gh >/dev/null 2>&1
  then
    usage_error "gh (GitHub CLI) is required on PATH"
  fi
  if [[ "${offline_mode}" -eq 0 ]] && [[ -z "${bundle_dir}" ]] && ! command -v curl >/dev/null 2>&1
  then
    usage_error "curl is required on PATH for online verification"
  fi
fi

# Resolve target formula list (keep array strictly nonempty for Bash 3.2 set -u).
targets=("__placeholder__")
target_count=0

if [[ "${formula_count}" -gt 0 ]]
then
  if [[ "${want_all}" -eq 1 ]]
  then
    usage_error "Cannot combine --all with explicit formula names"
  fi
  for raw_name in "${formula_args[@]}"
  do
    clean_name="${raw_name#artagon/aitools/}"
    if [[ ! "${clean_name}" =~ ^[a-z0-9][a-z0-9@._+-]*$ ]]
    then
      usage_error "Invalid formula name: ${raw_name}"
    fi
    if [[ "${target_count}" -eq 0 ]]
    then
      targets=("${clean_name}")
    else
      targets+=("${clean_name}")
    fi
    target_count=$((target_count + 1))
  done
else
  for rb_path in "${formula_dir}"/*.rb
  do
    [[ -f "${rb_path}" ]] || continue
    if grep -Eq '^[[:space:]]*bottle do$' "${rb_path}"
    then
      fname="$(basename "${rb_path}" .rb)"
      if [[ "${target_count}" -eq 0 ]]
      then
        targets=("${fname}")
      else
        targets+=("${fname}")
      fi
      target_count=$((target_count + 1))
    fi
  done
fi

if [[ "${target_count}" -eq 0 ]]
then
  usage_error "No bottled formulae found in ${formula_dir}"
fi

if [[ -n "${local_bottle_file}" ]] && [[ "${target_count}" -ne 1 ]]
then
  usage_error "--file PATH requires a single formula target"
fi

scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/verify-provenance.XXXXXX")"
mkdir -p "${scratch_dir}/cosign-tuf"

cosign_trusted_root=""
if [[ "${parse_only}" -eq 0 ]] && [[ -n "${effective_trusted_root}" ]]
then
  cosign_trusted_root="${scratch_dir}/sigstore-trusted-root.json"
  if ! prepare_cosign_trusted_root "${effective_trusted_root}" "${cosign_trusted_root}"
  then
    usage_error "Could not extract Sigstore TrustedRoot from ${effective_trusted_root}"
  fi
fi

if [[ "${parse_only}" -eq 0 ]] && [[ -n "${save_bundles_dir}" ]]
then
  mkdir -p "${save_bundles_dir}"
  gh attestation trusted-root >"${save_bundles_dir}/trusted_root.jsonl"
fi

results_jsonl="${scratch_dir}/results.jsonl"
: >"${results_jsonl}"

passed_count=0
failed_count=0

for target_formula in "${targets[@]}"
do
  if verify_one_formula "${target_formula}" "${results_jsonl}"
  then
    passed_count=$((passed_count + 1))
  else
    failed_count=$((failed_count + 1))
  fi
done

run_mode="online"
if [[ "${parse_only}" -eq 1 ]]
then
  run_mode="parse-only"
elif [[ "${offline_mode}" -eq 1 ]]
then
  run_mode="offline"
fi

overall_ok=true
if [[ "${failed_count}" -gt 0 ]]
then
  overall_ok=false
fi

if [[ "${json_output}" -eq 1 ]]
then
  jq -s \
    --arg mode "${run_mode}" \
    --argjson ok "${overall_ok}" \
    --argjson checked "${target_count}" \
    --argjson passed "${passed_count}" \
    --argjson failed "${failed_count}" \
    '{
      schema: "artagon-verify-provenance/v1",
      ok: $ok,
      mode: $mode,
      checked: $checked,
      passed: $passed,
      failed: $failed,
      results: .
    }' "${results_jsonl}"
else
  log_info ""
  log_info "Summary (${run_mode}): ${passed_count}/${target_count} passed, ${failed_count} failed."
fi

if [[ "${failed_count}" -gt 0 ]]
then
  exit 1
fi
exit 0
