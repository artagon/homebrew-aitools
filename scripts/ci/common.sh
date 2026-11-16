# shellcheck shell=bash
# Sourced CI input-validation and digest library (artagon-shell/shell-authoring/v1).
# Target contract: Bash 3.2+ sourced library (non-executable); macOS BSD + Linux GNU userland.
# Preserves caller shell options, IFS, traps, working directory, and environment on source.
# shellcheck disable=SC2310,SC2312

readonly CI_REPO_SLUG_RE='^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
readonly CI_SHA40_RE='^[0-9a-f]{40}$'
readonly CI_SHA256_RE='^[0-9a-f]{64}$'
readonly CI_UINT_RE='^[0-9]+$'
readonly CI_FORMULA_NAME_RE='^[a-z0-9][a-z0-9@._+-]*$'
readonly CI_SAFE_FILENAME_RE='^[A-Za-z0-9@.%_+-]+$'

ci::fail() {
  printf '::error::%s\n' "$*" >&2
  exit 1
}

ci::sha256_hex() {
  local path="$1"
  [[ -f "${path}" ]] || ci::fail "Cannot hash missing file: ${path}"
  if command -v sha256sum >/dev/null 2>&1
  then
    sha256sum -- "${path}" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1
  then
    shasum -a 256 -- "${path}" | awk '{ print $1 }'
  else
    openssl dgst -sha256 "${path}" | awk '{ print $NF }'
  fi
}

ci::require_repo_slug() {
  local val="$1" label="${2:-GITHUB_REPOSITORY}"
  [[ "${val}" =~ ${CI_REPO_SLUG_RE} ]] || ci::fail "Invalid ${label}: ${val}"
}

ci::require_main_ref() {
  local ref="${GITHUB_REF:-}"
  [[ "${ref}" = "refs/heads/main" ]] ||
    ci::fail "Workflow must run from refs/heads/main, not ${ref:-<unset>}"
}

ci::require_sha40() {
  local val="$1" label="${2:-commit SHA}"
  [[ "${val}" =~ ${CI_SHA40_RE} ]] ||
    ci::fail "${label} must be a 40-character lowercase hex SHA (got: ${val})"
}

ci::require_sha256() {
  local val="$1" label="${2:-SHA-256 digest}"
  [[ "${val}" =~ ${CI_SHA256_RE} ]] ||
    ci::fail "${label} must be a 64-character lowercase hex SHA-256 (got: ${val})"
}

ci::require_uint() {
  local val="$1" label="${2:-integer}"
  [[ "${val}" =~ ${CI_UINT_RE} ]] ||
    ci::fail "${label} must be a non-negative integer (got: ${val})"
}

ci::require_bool() {
  local val="$1" label="${2:-boolean}"
  [[ "${val}" = "true" || "${val}" = "false" ]] ||
    ci::fail "${label} must be true or false (got: ${val})"
}

ci::require_formula_name() {
  local val="$1" label="${2:-formula name}"
  [[ "${val}" =~ ${CI_FORMULA_NAME_RE} && "${val}" != *".."* ]] ||
    ci::fail "Invalid ${label}: ${val}"
}

ci::require_safe_filename() {
  local val="$1" label="${2:-filename}"
  [[ "${val}" =~ ${CI_SAFE_FILENAME_RE} && "${val}" != *".."* && "${val}" != -* ]] ||
    ci::fail "Unsafe ${label}: ${val}"
}
