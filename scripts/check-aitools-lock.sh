#!/usr/bin/env bash
# check-aitools-lock.sh — Verify versions/aitools-lock.json against Formula/*.rb,
# Nix Split-System closure metadata, and acli Cargo.lock statig/statsig policy.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland;
# requires awk, cmp, grep, jq, mktemp, sort, wc.
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
LIB_DIR="${SCRIPT_DIR}/lib"

readonly LOCK_SCHEMA="artagon-aitools-lock/v1"
readonly REQUIRED_PACKAGES=(agent-mail nats nats-server br bd acli)
readonly BINARY_PLATFORMS=(darwin-arm64 darwin-x86_64 linux-arm64 linux-x86_64)
readonly REQUIRED_STATIG_VERSION="0.4.1"
readonly SAFE_PKG_RE='^[a-z0-9][a-z0-9@._+-]*$'

lockfile="${REPO_ROOT}/versions/aitools-lock.json"
formula_dir="${REPO_ROOT}/Formula"
cargo_lock_override=""
json_output=0

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

usage() {
  cat >&2 <<'EOF'
Usage: check-aitools-lock.sh [OPTIONS]

Verify per-artifact/platform entries in versions/aitools-lock.json against
Formula/*.rb, Nix closure pins, and acli Cargo.lock crate policy.

Options:
  --lockfile PATH     Path to aitools-lock.json (default: versions/aitools-lock.json)
  --formula-dir PATH  Path to Formula directory (default: Formula)
  --cargo-lock PATH   Optional path to acli Cargo.lock for statig/statsig gate
  --json              Emit machine-readable JSON summary
  -h, --help          Show this help message
EOF
}

extract_formula_artifacts() {
  awk -f "${LIB_DIR}/extract-formula-artifacts.awk" "$1"
}

check_cargo_lock() {
  local cargo_lock="$1"
  local errors_file="$2"

  if [[ ! -f "${cargo_lock}" ]]
  then
    printf 'missing Cargo.lock file: %s\n' "${cargo_lock}" >>"${errors_file}"
    return 0
  fi

  awk -v req_ver="${REQUIRED_STATIG_VERSION}" -f "${LIB_DIR}/check-cargo-lock-statig.awk" "${cargo_lock}" >>"${errors_file}"
}

version_matches_url() {
  awk -v ver="$1" -v url="$2" -f "${LIB_DIR}/version-matches-url.awk" </dev/null
}

emit_result() {
  local errors_file="$1"
  local checked_count="$2"
  local err_count=0
  if [[ -s "${errors_file}" ]]
  then
    err_count="$(wc -l <"${errors_file}" | awk '{ print $1 }')"
  fi

  if [[ "${json_output}" -eq 1 ]]
  then
    jq -n \
      --arg schema "${LOCK_SCHEMA}" \
      --arg lockfile "${lockfile}" \
      --argjson checked "${checked_count}" \
      --argjson failed "${err_count}" \
      --rawfile errs "${errors_file}" \
      '{schema: $schema, ok: ($failed == 0), lockfile: $lockfile, checked: $checked, failed: $failed, errors: ($errs | split("\n") | map(select(length > 0)))}'
  else
    if [[ "${err_count}" -eq 0 ]]
    then
      printf 'aitools-lock: OK (%d artifact entries verified in %s)\n' "${checked_count}" "${lockfile}"
    else
      printf 'aitools-lock: FAILED (%d error(s) in %s)\n' "${err_count}" "${lockfile}" >&2
      local err_line=""
      while IFS= read -r err_line
      do
        [[ -n "${err_line}" ]] || continue
        printf '  - %s\n' "${err_line}" >&2
      done <"${errors_file}"
    fi
  fi

  [[ "${err_count}" -eq 0 ]]
}

parse_args() {
  while [[ $# -gt 0 ]]
  do
    case "$1" in
      --lockfile)
        if [[ $# -lt 2 ]]
        then
          echo "Missing argument for --lockfile" >&2
          usage
          exit 2
        fi
        lockfile="$2"
        shift
        ;;
      --lockfile=*)
        lockfile="${1#--lockfile=}"
        ;;
      --formula-dir)
        if [[ $# -lt 2 ]]
        then
          echo "Missing argument for --formula-dir" >&2
          usage
          exit 2
        fi
        formula_dir="$2"
        shift
        ;;
      --formula-dir=*)
        formula_dir="${1#--formula-dir=}"
        ;;
      --cargo-lock)
        if [[ $# -lt 2 ]]
        then
          echo "Missing argument for --cargo-lock" >&2
          usage
          exit 2
        fi
        cargo_lock_override="$2"
        shift
        ;;
      --cargo-lock=*)
        cargo_lock_override="${1#--cargo-lock=}"
        ;;
      --json)
        json_output=1
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        if [[ $# -gt 0 ]]
        then
          echo "Unexpected positional argument: $1" >&2
          usage
          exit 2
        fi
        break
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 2
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/check-aitools-lock.XXXXXX")"
  local errors_file="${work_dir}/errors.txt"
  : >"${errors_file}"

  if [[ ! -f "${lockfile}" ]]
  then
    printf 'lockfile not found: %s\n' "${lockfile}" >>"${errors_file}"
    emit_result "${errors_file}" 0
    return $?
  fi

  if ! jq -e '.' "${lockfile}" >/dev/null 2>&1
  then
    printf 'invalid JSON in lockfile: %s\n' "${lockfile}" >>"${errors_file}"
    emit_result "${errors_file}" 0
    return $?
  fi

  jq -r --arg schema "${LOCK_SCHEMA}" -f "${LIB_DIR}/check-aitools-lock.jq" "${lockfile}" >>"${errors_file}"

  local checked_count=0
  checked_count="$(jq -r 'if type == "object" and (.artifacts | type) == "array" then (.artifacts | length) else 0 end' "${lockfile}")"

  local pkg=""
  for pkg in "${REQUIRED_PACKAGES[@]}"
  do
    if ! jq -e --arg p "${pkg}" 'type == "object" and (.artifacts | type) == "array" and any(.artifacts[]; type == "object" and .package == $p)' "${lockfile}" >/dev/null
    then
      printf 'missing required package in lockfile: %s\n' "${pkg}" >>"${errors_file}"
    fi
  done

  local src_pkg=""
  for src_pkg in nats nats-server
  do
    if ! jq -e --arg p "${src_pkg}" 'type == "object" and (.artifacts | type) == "array" and any(.artifacts[]; type == "object" and .package == $p and .artifact_role == "source" and .platform == "all")' "${lockfile}" >/dev/null
    then
      printf 'package %s must declare source/all artifact entry\n' "${src_pkg}" >>"${errors_file}"
    fi
  done

  local acli_check="" exp_role="" rest="" exp_plat="" exp_res=""
  for acli_check in "source:all:" "guest-musl:linux-arm64:guest-aarch64-linux-musl" "guest-musl:linux-x86_64:guest-x86_64-linux-musl"
  do
    exp_role="${acli_check%%:*}"
    rest="${acli_check#*:}"
    exp_plat="${rest%%:*}"
    exp_res="${rest#*:}"
    if ! jq -e --arg r "${exp_role}" --arg pl "${exp_plat}" --arg res "${exp_res}" 'type == "object" and (.artifacts | type) == "array" and any(.artifacts[]; type == "object" and .package == "acli" and .artifact_role == $r and .platform == $pl and ((.resource // "") == $res))' "${lockfile}" >/dev/null
    then
      printf 'acli must declare artifact entry (%s, %s, resource=%s)\n' "${exp_role}" "${exp_plat}" "${exp_res:-none}" >>"${errors_file}"
    fi
  done

  local bin_pkg="" plat=""
  for bin_pkg in agent-mail br bd
  do
    for plat in "${BINARY_PLATFORMS[@]}"
    do
      if ! jq -e --arg p "${bin_pkg}" --arg pl "${plat}" 'type == "object" and (.artifacts | type) == "array" and any(.artifacts[]; type == "object" and .package == $p and .artifact_role == "binary" and .platform == $pl)' "${lockfile}" >/dev/null
      then
        printf 'package %s is missing required binary platform %s\n' "${bin_pkg}" "${plat}" >>"${errors_file}"
      fi
    done
  done

  local tracked_pkgs="${work_dir}/tracked-pkgs.txt"
  jq -r 'if type == "object" and (.artifacts | type) == "array" then ([.artifacts[] | select(type == "object" and (.package | type) == "string") | .package] | unique | .[]) else empty end' "${lockfile}" >"${tracked_pkgs}"

  local formula_path="" has_present="" has_staged="" lock_tsv="" formula_tsv="" formula_full_tsv=""
  while IFS= read -r pkg
  do
    [[ -n "${pkg}" ]] || continue
    if [[ ! "${pkg}" =~ ${SAFE_PKG_RE} ]]
    then
      continue
    fi
    formula_path="${formula_dir}/${pkg}.rb"
    has_present="$(jq -r --arg p "${pkg}" '[.artifacts[] | select(type == "object" and .package == $p and .status == "present")] | length' "${lockfile}")"
    has_staged="$(jq -r --arg p "${pkg}" '[.artifacts[] | select(type == "object" and .package == $p and .status == "staged")] | length' "${lockfile}")"

    if [[ "${has_present}" -gt 0 ]] && [[ "${has_staged}" -gt 0 ]]
    then
      printf 'package %s mixes status "present" and "staged" entries\n' "${pkg}" >>"${errors_file}"
      continue
    fi

    if [[ "${has_staged}" -gt 0 ]]
    then
      if [[ -f "${formula_path}" ]]
      then
        printf 'package %s is marked "staged" but %s already exists\n' "${pkg}" "${formula_path}" >>"${errors_file}"
      fi
      continue
    fi

    if [[ ! -f "${formula_path}" ]]
    then
      printf 'package %s is marked "present" but %s does not exist\n' "${pkg}" "${formula_path}" >>"${errors_file}"
      continue
    fi

    lock_tsv="${work_dir}/lock-${pkg}.usv"
    formula_tsv="${work_dir}/formula-${pkg}.usv"
    formula_full_tsv="${work_dir}/formula-full-${pkg}.tsv"

    jq -r --arg p "${pkg}" '.artifacts[] | select(type == "object" and .package == $p and .status == "present" and (.artifact_role | type) == "string" and (.platform | type) == "string" and (.url | type) == "string" and (.sha256 | type) == "string") | [.artifact_role, .platform, (if (.resource | type) == "string" then .resource else "" end), .url, .sha256] | join("\u001f")' "${lockfile}" | LC_ALL=C sort >"${lock_tsv}"

    if ! extract_formula_artifacts "${formula_path}" >"${formula_full_tsv}"
    then
      printf 'failed parsing %s: %s\n' "${formula_path}" "$(cat "${formula_full_tsv}")" >>"${errors_file}"
      continue
    fi
    awk -F '\t' 'BEGIN { OFS = "\037" } { print $1, $2, $3, $4, $5 }' "${formula_full_tsv}" | LC_ALL=C sort >"${formula_tsv}"

    if ! cmp -s "${lock_tsv}" "${formula_tsv}"
    then
      local l_role="" l_plat="" l_res="" row=""
      while IFS= read -r row
      do
        [[ -n "${row}" ]] || continue
        if ! grep -Fxq -- "${row}" "${formula_tsv}"
        then
          IFS=$'\037' read -r l_role l_plat l_res _ _ <<<"${row}"
          printf 'drift for %s (%s, %s%s): lockfile url/sha256 does not match %s\n' \
            "${pkg}" "${l_role}" "${l_plat}" "${l_res:+, resource=${l_res}}" "${formula_path}" >>"${errors_file}"
        fi
      done <"${lock_tsv}"

      while IFS= read -r row
      do
        [[ -n "${row}" ]] || continue
        if ! grep -Fxq -- "${row}" "${lock_tsv}"
        then
          IFS=$'\037' read -r l_role l_plat l_res _ _ <<<"${row}"
          printf 'untracked or drifted artifact in %s (%s, %s%s): missing matching entry in lockfile\n' \
            "${formula_path}" "${l_role}" "${l_plat}" "${l_res:+, resource=${l_res}}" >>"${errors_file}"
        fi
      done <"${formula_tsv}"
    fi

    # Verify every present lockfile entry's .version matches the formula's explicit version or literal URL.
    local lock_ver_tsv="${work_dir}/lock-ver-${pkg}.usv"
    jq -r --arg p "${pkg}" '.artifacts[] | select(type == "object" and .package == $p and .status == "present" and (.version | type) == "string" and (.artifact_role | type) == "string" and (.platform | type) == "string" and (.url | type) == "string") | [.artifact_role, .platform, (if (.resource | type) == "string" then .resource else "" end), .version, .url] | join("\u001f")' "${lockfile}" >"${lock_ver_tsv}"

    local v_role="" v_plat="" v_res="" v_ver="" v_url="" f_exp_ver=""
    while IFS=$'\037' read -r v_role v_plat v_res v_ver v_url
    do
      [[ -n "${v_role}" ]] || continue
      f_exp_ver="$(awk -F '\t' -v r="${v_role}" -v p="${v_plat}" -v res="${v_res}" '$1 == r && $2 == p && $3 == res { print $6; exit }' "${formula_full_tsv}")"
      if [[ -n "${f_exp_ver}" ]]
      then
        if [[ "${v_ver}" != "${f_exp_ver}" ]]
        then
          printf 'version drift for %s (%s, %s%s): lockfile has %s, %s declares %s\n' \
            "${pkg}" "${v_role}" "${v_plat}" "${v_res:+, resource=${v_res}}" "${v_ver}" "${formula_path}" "${f_exp_ver}" >>"${errors_file}"
        fi
      else
        if ! version_matches_url "${v_ver}" "${v_url}"
        then
          printf 'version drift for %s (%s, %s%s): lockfile version %s does not appear in url %s\n' \
            "${pkg}" "${v_role}" "${v_plat}" "${v_res:+, resource=${v_res}}" "${v_ver}" "${v_url}" >>"${errors_file}"
        fi
      fi
    done <"${lock_ver_tsv}"
  done <"${tracked_pkgs}"

  local cargo_lock_path="${cargo_lock_override}"
  if [[ -z "${cargo_lock_path}" ]]
  then
    local lock_declared_cargo=""
    lock_declared_cargo="$(jq -r 'if type == "object" and (.nix_closure | type) == "object" and (.nix_closure.acli_cargo_lock | type) == "string" then .nix_closure.acli_cargo_lock else empty end' "${lockfile}")"
    if [[ -n "${lock_declared_cargo}" ]]
    then
      if [[ "${lock_declared_cargo}" != /* ]] && [[ "/${lock_declared_cargo}/" != *"/../"* ]]
      then
        local base_root=""
        base_root="$(cd "${formula_dir}/.." && pwd -P)"
        cargo_lock_path="${base_root}/${lock_declared_cargo}"
      fi
    fi
  fi

  local acli_present_count=""
  acli_present_count="$(jq -r 'if type == "object" and (.artifacts | type) == "array" then ([.artifacts[] | select(type == "object" and .package == "acli" and .status == "present")] | length) else 0 end' "${lockfile}")"
  if [[ -n "${cargo_lock_path}" ]]
  then
    if [[ -f "${cargo_lock_path}" ]] || [[ -n "${cargo_lock_override}" ]] || [[ "${acli_present_count}" -gt 0 ]]
    then
      check_cargo_lock "${cargo_lock_path}" "${errors_file}"
    fi
  fi

  emit_result "${errors_file}" "${checked_count}"
}

main "$@"
