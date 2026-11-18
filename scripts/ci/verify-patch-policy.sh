#!/usr/bin/env bash
# Deterministic README marker updater and publish.yml staged-patch policy validator.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland; requires awk, cmp, git.
# Subcommands:
#   replace-readme <readme_path> <out_path> <block_path>
#   verify-readme-git <head_sha>
#   verify-formula-git <head_sha> <formula_path>
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/ci/common.sh
source "${CI_DIR}/common.sh"

readonly BEGIN_MARKER="<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->"
readonly END_MARKER="<!-- END BOTTLE_PROVENANCE_TABLE -->"
readonly FORMULA_REL_RE='^Formula/[a-z0-9][a-z0-9@._+-]*\.rb$'
readonly ROOT_URL_STMT_RE='^    root_url "https://github\.com/artagon/homebrew-aitools/releases/download/[A-Za-z0-9@.%_+-]+"$'
readonly REBUILD_STMT_RE='^    rebuild [0-9]+$'
readonly SHA256_STMT_RE='^    sha256 +(cellar: (:any|:any_skip_relocation|"/[A-Za-z0-9_./+-]+"), +)?[a-z0-9_]+: +"[0-9a-f]{64}"$'

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
  printf 'Usage: verify-patch-policy.sh <replace-readme|verify-readme-git|verify-formula-git> ...\n' >&2
  exit 2
}

validate_readme_markers() {
  local path="$1"
  [[ -f "${path}" ]] || return 1
  awk -v b="${BEGIN_MARKER}" -v e="${END_MARKER}" '
    $0 == b {
      b_count++
      b_line = NR
      next
    }
    $0 == e {
      e_count++
      e_line = NR
      next
    }
    index($0, b) > 0 || index($0, e) > 0 {
      inline_err = 1
    }
    END {
      bad = (inline_err || b_count != 1 || e_count != 1 || b_line >= e_line)
      exit(bad ? 1 : 0)
    }
  ' "${path}"
}

strip_readme_table() {
  local in_path="$1"
  local out_path="$2"
  validate_readme_markers "${in_path}" || return 1
  awk -v b="${BEGIN_MARKER}" -v e="${END_MARKER}" '
    $0 == b {
      print b
      in_table = 1
      next
    }
    $0 == e {
      print e
      in_table = 0
      next
    }
    !in_table {
      print $0
    }
  ' "${in_path}" >"${out_path}"
}

cmd_replace_readme() {
  local readme_path="$1"
  local out_path="$2"
  local block_path="$3"

  if ! validate_readme_markers "${readme_path}"
  then
    printf 'Missing, duplicate, or inline BOTTLE_PROVENANCE_TABLE markers in %s\n' "${readme_path}" >&2
    return 1
  fi
  if ! validate_readme_markers "${block_path}"
  then
    printf 'Invalid replacement BOTTLE_PROVENANCE_TABLE block in %s\n' "${block_path}" >&2
    return 1
  fi

  awk -v b="${BEGIN_MARKER}" -v e="${END_MARKER}" -v block_file="${block_path}" '
    $0 == b {
      while ((getline bline < block_file) > 0) {
        print bline
      }
      close(block_file)
      in_table = 1
      next
    }
    $0 == e {
      in_table = 0
      next
    }
    !in_table {
      print $0
    }
  ' "${readme_path}" >"${out_path}"
}

cmd_verify_readme_git() {
  local head_sha="$1"
  [[ "${head_sha}" =~ ${CI_SHA40_RE} ]] || return 1

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/verify-patch-policy.XXXXXX")"
  git show "${head_sha}:README.md" >"${work_dir}/before.md" 2>/dev/null || return 1
  git show "HEAD:README.md" >"${work_dir}/after.md" 2>/dev/null || return 1

  strip_readme_table "${work_dir}/before.md" "${work_dir}/before.stripped" || return 1
  strip_readme_table "${work_dir}/after.md" "${work_dir}/after.stripped" || return 1

  cmp -s "${work_dir}/before.stripped" "${work_dir}/after.stripped"
}

readonly FORMULA_BODY_STOP_RE='^  (def (install|caveats|post_install)|test [d]o)$|^__END__$'

count_and_extract_bottle() {
  local formula_file="$1"
  local inner_out="$2"
  awk -v inner="${inner_out}" -v stop_re="${FORMULA_BODY_STOP_RE}" '
    $0 ~ stop_re && in_bottle {
      bad = 1
      exit 1
    }
    $0 ~ stop_re {
      exit 0
    }
    /^  bottle do$/ && in_bottle {
      bad = 1
      exit 1
    }
    /^  bottle do$/ {
      in_bottle = 1
      count++
      next
    }
    in_bottle && /^  end$/ {
      in_bottle = 0
      next
    }
    in_bottle && inner != "" {
      print $0 > inner
      next
    }
    in_bottle {
      next
    }
    END {
      if(bad || in_bottle) {
        exit 1
      }
      printf "%d\n", count
    }
  ' "${formula_file}"
}

strip_single_bottle_block() {
  local formula_file="$1"
  local out_file="$2"
  awk -v stop_re="${FORMULA_BODY_STOP_RE}" '
    {
      lines[NR] = $0
    }
    !stopped && ($0 ~ stop_re) {
      stopped = 1
      next
    }
    !stopped && $0 == "  bottle do" && b_start == 0 {
      b_start = NR
      in_bottle = 1
      next
    }
    !stopped && in_bottle && $0 == "  end" {
      b_end = NR
      in_bottle = 0
    }
    END {
      skip_from = (b_start == 0) ? (NR + 1) : b_start
      skip_to = (b_start == 0) ? 0 : b_end
      has_after_blank = (b_start > 0 && b_end < NR && lines[b_end + 1] == "")
      has_before_blank = (!has_after_blank && b_start > 1 && lines[b_start - 1] == "")
      skip_to = has_after_blank ? (b_end + 1) : skip_to
      skip_from = has_before_blank ? (b_start - 1) : skip_from
      for (i = 1; i <= NR; i++) {
        keep = (i < skip_from || i > skip_to)
        keep && printed = (print_line(lines[i]))
      }
    }
    function print_line(s) {
      print s
      return 1
    }
  ' "${formula_file}" >"${out_file}"
}

cmd_verify_formula_git() {
  local head_sha="$1"
  local formula_path="$2"
  [[ "${head_sha}" =~ ${CI_SHA40_RE} ]] || return 1
  [[ "${formula_path}" =~ ${FORMULA_REL_RE} && "${formula_path}" != *".."* ]] || return 1

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/verify-patch-policy.XXXXXX")"
  git show "${head_sha}:${formula_path}" >"${work_dir}/before.rb" 2>/dev/null || return 1
  git show "HEAD:${formula_path}" >"${work_dir}/after.rb" 2>/dev/null || return 1

  local before_count=""
  local after_count=""
  : >"${work_dir}/after.inner"
  before_count="$(count_and_extract_bottle "${work_dir}/before.rb" "")" || return 1
  after_count="$(count_and_extract_bottle "${work_dir}/after.rb" "${work_dir}/after.inner")" || return 1

  if [[ "${after_count}" -ne 1 || "${before_count}" -gt 1 ]]
  then
    return 1
  fi

  local non_empty=0
  local stmt=""
  while IFS= read -r stmt
  do
    [[ -z "${stmt}" ]] && continue
    non_empty=$((non_empty + 1))
    if [[ "${stmt}" =~ ${ROOT_URL_STMT_RE} ]] ||
       [[ "${stmt}" =~ ${REBUILD_STMT_RE} ]] ||
       [[ "${stmt}" =~ ${SHA256_STMT_RE} ]]
    then
      continue
    fi
    return 1
  done <"${work_dir}/after.inner"

  [[ "${non_empty}" -gt 0 ]] || return 1

  strip_single_bottle_block "${work_dir}/before.rb" "${work_dir}/before.stripped"
  strip_single_bottle_block "${work_dir}/after.rb" "${work_dir}/after.stripped"

  cmp -s "${work_dir}/before.stripped" "${work_dir}/after.stripped"
}

[[ "$#" -ge 1 ]] || usage
mode="$1"
case "${mode}" in
  replace-readme)
    [[ "$#" -eq 4 ]] || usage
    cmd_replace_readme "$2" "$3" "$4"
    ;;
  verify-readme-git)
    [[ "$#" -eq 2 ]] || usage
    cmd_verify_readme_git "$2"
    ;;
  verify-formula-git)
    [[ "$#" -eq 3 ]] || usage
    cmd_verify_formula_git "$2" "$3"
    ;;
  *)
    usage
    ;;
esac
