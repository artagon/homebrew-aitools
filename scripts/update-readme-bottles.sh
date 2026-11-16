#!/usr/bin/env bash
# Deterministically render or verify the published bottle versions, SHA-256 digests,
# Sigstore/SLSA provenance bundles, and SBOM links table in README.md from Formula/*.rb.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland; requires awk, cmp, jq.
# Usage:
#   ./scripts/update-readme-bottles.sh            # update README.md atomically in place
#   ./scripts/update-readme-bottles.sh --check    # exit 0 if up to date, 1 if stale
#   ./scripts/update-readme-bottles.sh --stdout   # print generated markdown block
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="${PROVENANCE_REPO_ROOT:-$(cd "${script_dir}/.." && pwd -P)}"
readme_path="${README_BOTTLES_FILE:-${repo_root}/README.md}"
readonly VERIFIER="${script_dir}/verify-provenance.sh"
readonly POLICY_HELPER="${script_dir}/ci/verify-patch-policy.sh"
readonly BEGIN_MARKER="<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->"
readonly END_MARKER="<!-- END BOTTLE_PROVENANCE_TABLE -->"

tmp_block=""
tmp_readme=""
# Invoked indirectly via `trap cleanup EXIT`.
# shellcheck disable=SC2329
cleanup() {
  local rc=$?
  if [[ -n "${tmp_block}" && -e "${tmp_block}" ]]
  then
    rm -f -- "${tmp_block}" || true
  fi
  if [[ -n "${tmp_readme}" && -e "${tmp_readme}" ]]
  then
    rm -f -- "${tmp_readme}" || true
  fi
  return "${rc}"
}
trap cleanup EXIT

die() {
  printf 'update-readme-bottles: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: update-readme-bottles.sh [--check | --stdout | --help]
EOF
  exit 2
}

mode="write"
if [[ "$#" -gt 1 ]]
then
  usage
elif [[ "$#" -eq 1 ]]
then
  case "$1" in
    --check)
      mode="check"
      ;;
    --stdout)
      mode="stdout"
      ;;
    -h | --help)
      cat <<'EOF'
Usage: update-readme-bottles.sh [--check | --stdout | --help]
EOF
      exit 0
      ;;
    *)
      usage
      ;;
  esac
fi

[[ -f "${VERIFIER}" ]] || die "Missing verifier script: ${VERIFIER}"
[[ -f "${POLICY_HELPER}" ]] || die "Missing helper script: ${POLICY_HELPER}"

parsed_json=""
parsed_json="$(PROVENANCE_REPO_ROOT="${repo_root}" bash "${VERIFIER}" --parse-only --all-tags --json)"

render_block() {
  printf '%s\n' "${BEGIN_MARKER}"
  cat <<'EOF'
<!-- Auto-generated from Formula/*.rb by scripts/update-readme-bottles.sh (and refreshed automatically by publish.yml). Do not edit manually. -->

All published bottles are attested on `refs/heads/main` and indexed in the [GitHub Attestations transparency log](https://github.com/artagon/homebrew-aitools/attestations).

| Formula | Platform & Version | Bottle & SHA-256 | Provenance Certificates & Proofs | Signed SBOMs |
| :--- | :--- | :--- | :--- | :--- |
EOF
  printf '%s\n' "${parsed_json}" |
    jq -r '
      .results
      | group_by(.formula)
      | sort_by(.[0].formula)
      | map(.[])[]
      | (if .rebuild > 0 then "`\(.bottle_tag)` · `\(.pkg_version)` (rebuild \(.rebuild))" else "`\(.bottle_tag)` · `\(.pkg_version)`" end) as $ver
      | (.expected_sha256[0:12]) as $short_sha
      | "\(.root_url)/\(.release_filename)" as $base
      | "https://github.com/artagon/homebrew-aitools/releases/tag/\(.release_tag)" as $rel_page
      | "https://api.github.com/repos/artagon/homebrew-aitools/attestations/sha256:\(.expected_sha256)" as $api_proof
      | "| [`\(.formula)`](Formula/\(.formula).rb) | \($ver) | [Release](\($rel_page)) · [Bottle](\($base)) · [`\($short_sha)…`](\($base).sha256) | [SLSA v1](\($base).intoto.jsonl) · [Lineage v1](\($base).lineage.intoto.jsonl) · [Sigstore](\($base).sigstore.json) · [Summary](\($base).provenance.json) · [API Proof](\($api_proof)) | [SPDX 2.3](\($base).spdx.json) · [SPDX Sig](\($base).spdx.sigstore.json) · [CycloneDX 1.6](\($base).cdx.json) |"
    '
  printf '%s\n' "${END_MARKER}"
}

if [[ "${mode}" = "stdout" ]]
then
  render_block
  exit 0
fi

[[ -f "${readme_path}" ]] || die "README not found: ${readme_path}"
readme_dir="$(cd "$(dirname "${readme_path}")" && pwd -P)"
readme_base="$(basename "${readme_path}")"

tmp_block="$(mktemp "${readme_dir}/.${readme_base}.block.XXXXXX")"
tmp_readme="$(mktemp "${readme_dir}/.${readme_base}.tmp.XXXXXX")"
render_block >"${tmp_block}"

bash "${POLICY_HELPER}" replace-readme "${readme_path}" "${tmp_readme}" "${tmp_block}" ||
  die "Failed to update ${readme_path}"

if [[ "${mode}" = "check" ]]
then
  if ! cmp -s "${readme_path}" "${tmp_readme}"
  then
    die "${readme_path} bottle provenance table is out of date; run ./scripts/update-readme-bottles.sh"
  fi
  exit 0
fi

if ! cmp -s "${readme_path}" "${tmp_readme}"
then
  chmod 0644 "${tmp_readme}"
  mv -f -- "${tmp_readme}" "${readme_path}"
  tmp_readme=""
fi
