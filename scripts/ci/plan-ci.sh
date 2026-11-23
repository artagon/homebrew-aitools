#!/usr/bin/env bash
# Plan scoped CI lint/test flags and dependency-aware bottle shards for
# `.github/workflows/tests.yml`.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland;
# requires awk, git, jq, mktemp, sort.
# Inputs (via environment, never shell-interpolated in YAML):
#   EVENT_NAME, BASE_SHA, HEAD_SHA, PUSH_BEFORE, INPUT_FORMULAE,
#   INPUT_INCLUDE_MACOS, PR_LABELS_JSON, GITHUB_OUTPUT,
#   optional PLAN_MAX_SHARDS (default 5).
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/ci/common.sh
source "${CI_DIR}/common.sh"

readonly TAP_PREFIX="artagon/aitools"
readonly ZERO_SHA="0000000000000000000000000000000000000000"
readonly MACOS_BOTTLE_LABEL="build-macos-bottles"
readonly LINUX_MATRIX_OSES_JSON='["ubuntu-24.04","ubuntu-24.04-arm"]'
readonly ALL_MATRIX_OSES_JSON='["macos-26","ubuntu-24.04","ubuntu-24.04-arm"]'
readonly FORMULA_PATH_RE='^Formula/([a-z0-9][a-z0-9@._+-]*)\.rb$'
readonly FULL_FORMULA_RE='^artagon/aitools/([a-z0-9][a-z0-9@._+-]*)$'
readonly STYLE_FILE_RE='^(Formula/[^/]+\.rb|Casks/[^/]+\.rb|scripts/(.+/)?[^/]+\.sh|\.github/workflows/[^/]+\.yml)$'

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

require_formula_path() {
  local path="$1"
  if [[ "${path}" == Formula/* ]]
  then
    if [[ ! "${path}" =~ ${FORMULA_PATH_RE} || "${path}" == *".."* ]]
    then
      ci::fail "Unexpected or invalid file under Formula/: ${path}"
    fi
  fi
}

file_has_line() {
  local needle="$1"
  local haystack="$2"
  [[ -s "${haystack}" ]] || return 1
  grep -Fxq -- "${needle}" "${haystack}"
}

append_unique_sorted() {
  local src="$1"
  local dst="$2"
  if [[ -s "${src}" ]]
  then
    LC_ALL=C sort -u "${src}" >"${dst}"
  else
    : >"${dst}"
  fi
}

readonly FORMULA_BODY_STOP_RE='^  (def (install|caveats|post_install)|test [d]o)$|^__END__$'

parse_intra_tap_deps() {
  local f="" src=""
  local -a formula_files=()
  shopt -s nullglob
  formula_files=(Formula/*.rb)
  shopt -u nullglob
  for f in ${formula_files[@]+"${formula_files[@]}"}
  do
    [[ -f "${f}" ]] || continue
    src="$(basename "${f}" .rb)"
    awk -v src="${src}" -v stop_re="${FORMULA_BODY_STOP_RE}" '
      $0 ~ stop_re { exit }
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*depends_on[[:space:]]+["\047]artagon\/aitools\/[a-z0-9][a-z0-9@._+-]*["\047]/ {
        line = $0
        sub(/^[[:space:]]*depends_on[[:space:]]+["\047]artagon\/aitools\//, "", line)
        dep = line
        sub(/["\047].*$/, "", dep)
        rest = line
        sub(/^[^"\047]*["\047]/, "", rest)
        sub(/#.*$/, "", rest)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", rest)
        kind = "runtime"
        if(rest ~ /^=>[[:space:]]*:build$/ || rest ~ /^=>[[:space:]]*\[[[:space:]]*:build[[:space:]]*\]$/) {
          kind = "build"
        }
        printf "%s\t%s\t%s\n", src, dep, kind
      }
    ' "${f}"
  done
}

build_shards_tsv() {
  local changed_file="$1"
  local deps_file="$2"
  local max_shards="$3"
  awk -F '\t' -v max_shards="${max_shards}" '
    function find_root(x) {
      while(parent[x] != x) {
        x = parent[x]
      }
      return x
    }
    function union_nodes(a, b,    ra, rb) {
      ra = find_root(a)
      rb = find_root(b)
      if(ra != rb) {
        if(ra < rb) {
          parent[rb] = ra
        } else {
          parent[ra] = rb
        }
      }
    }
    NR == FNR {
      if($0 != "") {
        n++
        names[n] = $0
        idx[$0] = n
        parent[n] = n
      }
      next
    }
    {
      if(($1 in idx) && ($2 in idx)) {
        union_nodes(idx[$1], idx[$2])
      }
    }
    END {
      if(n == 0) {
        exit 0
      }
      num_comp = 0
      for(i = 1; i <= n; i++) {
        r = find_root(i)
        if(!(r in comp_id)) {
          num_comp++
          comp_id[r] = num_comp
          comp_size[num_comp] = 0
          comp_first[num_comp] = names[i]
          comp_members[num_comp] = ""
        }
        c = comp_id[r]
        comp_size[c]++
        comp_members[c] = (comp_members[c] == "") ? names[i] : (comp_members[c] " " names[i])
      }

      for(i = 1; i <= num_comp; i++) {
        order[i] = i
      }
      for(i = 2; i <= num_comp; i++) {
        key = order[i]
        j = i - 1
        while(j >= 1) {
          prev = order[j]
          if(comp_size[prev] < comp_size[key] ||
             (comp_size[prev] == comp_size[key] && comp_first[prev] > comp_first[key])) {
            order[j + 1] = order[j]
            j--
          } else {
            break
          }
        }
        order[j + 1] = key
      }

      num_shards = (num_comp < max_shards) ? num_comp : max_shards
      for(s = 1; s <= num_shards; s++) {
        shard_size[s] = 0
        shard_members[s] = ""
      }

      for(i = 1; i <= num_comp; i++) {
        c = order[i]
        best = 1
        for(s = 2; s <= num_shards; s++) {
          if(shard_size[s] < shard_size[best]) {
            best = s
          }
        }
        shard_size[best] += comp_size[c]
        shard_members[best] = (shard_members[best] == "") ? comp_members[c] : (shard_members[best] " " comp_members[c])
      }

      for(s = 1; s <= num_shards; s++) {
        printf "%d\t%s\n", s, shard_members[s]
      }
    }
  ' "${changed_file}" "${deps_file}"
}

main() {
  local event_name="${EVENT_NAME:-}"
  local base_sha="${BASE_SHA:-}"
  local head_sha="${HEAD_SHA:-}"
  local push_before="${PUSH_BEFORE:-}"
  local input_formulae="${INPUT_FORMULAE:-}"
  local input_include_macos="${INPUT_INCLUDE_MACOS:-false}"
  local pr_labels_json="${PR_LABELS_JSON:-[]}"
  local github_output="${GITHUB_OUTPUT:-}"
  local max_shards="${PLAN_MAX_SHARDS:-5}"

  [[ -n "${github_output}" ]] || ci::fail "GITHUB_OUTPUT must be set"
  case "${event_name}" in
    pull_request | workflow_dispatch | push) ;;
    *)
      ci::fail "Unsupported EVENT_NAME: ${event_name:-<unset>}"
      ;;
  esac
  ci::require_bool "${input_include_macos}" "INPUT_INCLUDE_MACOS"
  jq -e 'type == "array" and all(.[]; type == "string")' <<<"${pr_labels_json}" >/dev/null 2>&1 ||
    ci::fail "PR_LABELS_JSON must be a JSON array of label names"
  ci::require_uint "${max_shards}" "PLAN_MAX_SHARDS"
  [[ "${max_shards}" -ge 1 ]] || ci::fail "PLAN_MAX_SHARDS must be >= 1 (got: ${max_shards})"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    ci::fail "plan-ci.sh must run inside a git work tree"

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/plan-ci.XXXXXX")"
  local raw_acmr="${work_dir}/raw-acmr.txt"
  local raw_added="${work_dir}/raw-added.txt"
  local raw_deleted="${work_dir}/raw-deleted.txt"
  local acmr_file="${work_dir}/acmr.txt"
  local deleted_file="${work_dir}/deleted.txt"
  local all_changed_file="${work_dir}/all-changed.txt"
  local changed_formulae_raw="${work_dir}/changed-formulae-raw.txt"
  local changed_formulae_file="${work_dir}/changed-formulae.txt"
  local added_formulae_raw="${work_dir}/added-formulae-raw.txt"
  local added_formulae_file="${work_dir}/added-formulae.txt"
  local deleted_formulae_raw="${work_dir}/deleted-formulae-raw.txt"
  local deleted_formulae_file="${work_dir}/deleted-formulae.txt"
  local style_files_raw="${work_dir}/style-files-raw.txt"
  local style_files_file="${work_dir}/style-files.txt"
  local deps_file="${work_dir}/deps.tsv"
  local shards_tsv="${work_dir}/shards.tsv"
  local shards_jsonl="${work_dir}/shards.jsonl"

  : >"${raw_acmr}"
  : >"${raw_added}"
  : >"${raw_deleted}"
  : >"${changed_formulae_raw}"
  : >"${added_formulae_raw}"
  : >"${deleted_formulae_raw}"
  : >"${style_files_raw}"
  : >"${shards_jsonl}"

  local explicit_formulae=0
  local diff_ref=""
  local -a input_tokens=()
  local token="" name="" path=""

  case "${event_name}" in
    pull_request)
      ci::require_sha40 "${base_sha}" "BASE_SHA"
      ci::require_sha40 "${head_sha}" "HEAD_SHA"
      git cat-file -e "${base_sha}^{commit}" 2>/dev/null ||
        ci::fail "BASE_SHA commit not found in git history: ${base_sha}"
      git -c core.quotepath=false diff --name-only --no-renames --diff-filter=ACMR "${base_sha}" HEAD >"${raw_acmr}"
      git -c core.quotepath=false diff --name-only --no-renames --diff-filter=A "${base_sha}" HEAD -- 'Formula/' >"${raw_added}"
      git -c core.quotepath=false diff --name-only --no-renames --diff-filter=D "${base_sha}" HEAD >"${raw_deleted}"
      ;;
    workflow_dispatch)
      if git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null
      then
        diff_ref="refs/remotes/origin/main"
      elif git rev-parse --verify --quiet refs/heads/main >/dev/null
      then
        diff_ref="refs/heads/main"
      fi
      if [[ -n "${diff_ref}" ]] && git merge-base "${diff_ref}" HEAD >/dev/null 2>&1
      then
        git -c core.quotepath=false diff --name-only --no-renames --diff-filter=ACMR "${diff_ref}...HEAD" >"${raw_acmr}"
        git -c core.quotepath=false diff --name-only --no-renames --diff-filter=A "${diff_ref}...HEAD" -- 'Formula/' >"${raw_added}"
        git -c core.quotepath=false diff --name-only --no-renames --diff-filter=D "${diff_ref}...HEAD" >"${raw_deleted}"
      fi
      if [[ -n "${input_formulae}" ]]
      then
        IFS=$' \t\r\n' read -r -a input_tokens <<<"${input_formulae}" || true
        if [[ "${#input_tokens[@]}" -gt 0 ]]
        then
          explicit_formulae=1
          for token in "${input_tokens[@]}"
          do
            if [[ ! "${token}" =~ ${FULL_FORMULA_RE} || "${token}" == *".."* ]]
            then
              ci::fail "Invalid formula token in INPUT_FORMULAE: ${token}"
            fi
            name="${BASH_REMATCH[1]}"
            [[ -f "Formula/${name}.rb" ]] ||
              ci::fail "Formula file does not exist for INPUT_FORMULAE token: ${token}"
            printf '%s\n' "${name}" >>"${changed_formulae_raw}"
            printf 'Formula/%s.rb\n' "${name}" >>"${raw_acmr}"
          done
        fi
      fi
      ;;
    push)
      if [[ "${push_before}" =~ ${CI_SHA40_RE} && "${push_before}" != "${ZERO_SHA}" ]] &&
         git cat-file -e "${push_before}^{commit}" 2>/dev/null
      then
        git -c core.quotepath=false diff --name-only --no-renames --diff-filter=ACMR "${push_before}" HEAD >"${raw_acmr}"
        git -c core.quotepath=false diff --name-only --no-renames --diff-filter=D "${push_before}" HEAD >"${raw_deleted}"
      elif git rev-parse --verify --quiet HEAD~1 >/dev/null
      then
        git -c core.quotepath=false diff --name-only --no-renames --diff-filter=ACMR HEAD~1 HEAD >"${raw_acmr}"
        git -c core.quotepath=false diff --name-only --no-renames --diff-filter=D HEAD~1 HEAD >"${raw_deleted}"
      else
        git -c core.quotepath=false ls-files >"${raw_acmr}"
      fi
      ;;
    *) ;;
  esac

  append_unique_sorted "${raw_acmr}" "${acmr_file}"
  append_unique_sorted "${raw_deleted}" "${deleted_file}"
  cat "${acmr_file}" "${deleted_file}" >"${work_dir}/combined.txt"
  append_unique_sorted "${work_dir}/combined.txt" "${all_changed_file}"

  while IFS= read -r path
  do
    [[ -n "${path}" ]] || continue
    require_formula_path "${path}"
    if [[ "${explicit_formulae}" -eq 0 && "${event_name}" != "push" && "${path}" =~ ${FORMULA_PATH_RE} ]]
    then
      printf '%s\n' "${BASH_REMATCH[1]}" >>"${changed_formulae_raw}"
    fi
    if [[ -f "${path}" && "${path}" =~ ${STYLE_FILE_RE} ]]
    then
      printf '%s\n' "${path}" >>"${style_files_raw}"
    fi
  done <"${acmr_file}"

  while IFS= read -r path
  do
    [[ -n "${path}" ]] || continue
    require_formula_path "${path}"
    if [[ "${event_name}" != "push" && "${path}" =~ ${FORMULA_PATH_RE} ]]
    then
      printf '%s\n' "${BASH_REMATCH[1]}" >>"${deleted_formulae_raw}"
    fi
  done <"${deleted_file}"

  append_unique_sorted "${changed_formulae_raw}" "${changed_formulae_file}"
  append_unique_sorted "${deleted_formulae_raw}" "${deleted_formulae_file}"
  append_unique_sorted "${style_files_raw}" "${style_files_file}"

  while IFS= read -r path
  do
    [[ -n "${path}" ]] || continue
    require_formula_path "${path}"
    if [[ "${event_name}" != "push" && "${path}" =~ ${FORMULA_PATH_RE} ]]
    then
      name="${BASH_REMATCH[1]}"
      if file_has_line "${name}" "${changed_formulae_file}"
      then
        printf '%s\n' "${name}" >>"${added_formulae_raw}"
      fi
    fi
  done <"${raw_added}"
  append_unique_sorted "${added_formulae_raw}" "${added_formulae_file}"

  parse_intra_tap_deps >"${deps_file}"

  local has_intra_tap_runtime_deps="false"
  if [[ "${event_name}" != "push" && -s "${changed_formulae_file}" && -s "${deps_file}" ]]
  then
    local dep_src="" dep_target="" dep_kind=""
    while IFS=$'\t' read -r dep_src dep_target dep_kind
    do
      [[ -n "${dep_src}" ]] || continue
      if [[ "${dep_kind}" != "build" ]] &&
         (file_has_line "${dep_src}" "${changed_formulae_file}" || file_has_line "${dep_target}" "${changed_formulae_file}")
      then
        has_intra_tap_runtime_deps="true"
        break
      fi
    done <"${deps_file}"
  fi

  local shards_json="[]"
  local shard_count=0
  local has_formulae="false"
  local use_merge="false"

  if [[ "${event_name}" != "push" && -s "${changed_formulae_file}" ]]
  then
    build_shards_tsv "${changed_formulae_file}" "${deps_file}" "${max_shards}" >"${shards_tsv}"
    local shard_idx="" members_str="" member=""
    local shard_formulae_csv="" shard_added_csv="" has_ripwire="false"
    local -a shard_members_arr=()
    local sorted_members_file="${work_dir}/shard-members.txt"
    while IFS=$'\t' read -r shard_idx members_str
    do
      [[ -n "${shard_idx}" ]] || continue
      shard_count=$((shard_count + 1))
      shard_formulae_csv=""
      shard_added_csv=""
      has_ripwire="false"
      IFS=' ' read -r -a shard_members_arr <<<"${members_str}"
      : >"${sorted_members_file}"
      for member in ${shard_members_arr[@]+"${shard_members_arr[@]}"}
      do
        [[ -n "${member}" ]] && printf '%s\n' "${member}" >>"${sorted_members_file}"
      done
      while IFS= read -r member
      do
        [[ -n "${member}" ]] || continue
        shard_formulae_csv="${shard_formulae_csv:+${shard_formulae_csv},}${TAP_PREFIX}/${member}"
        if file_has_line "${member}" "${added_formulae_file}"
        then
          shard_added_csv="${shard_added_csv:+${shard_added_csv},}${TAP_PREFIX}/${member}"
        fi
        if [[ "${member}" = "ripwire" ]]
        then
          has_ripwire="true"
        fi
      done < <(LC_ALL=C sort -u "${sorted_members_file}")

      jq -c -n \
        --arg id "shard-${shard_idx}" \
        --arg formulae "${shard_formulae_csv}" \
        --arg added "${shard_added_csv}" \
        --argjson has_ripwire "${has_ripwire}" \
        '{
          id: $id,
          formulae: $formulae,
          added: $added,
          has_ripwire: $has_ripwire
        }' >>"${shards_jsonl}"
    done <"${shards_tsv}"

    if [[ "${shard_count}" -gt 0 ]]
    then
      has_formulae="true"
      shards_json="$(jq -c -s '.' "${shards_jsonl}")"
      if [[ "${shard_count}" -gt 1 ]]
      then
        use_merge="true"
      fi
    fi
  fi

  local deleted_formulae_csv=""
  if [[ "${event_name}" != "push" && -s "${deleted_formulae_file}" ]]
  then
    while IFS= read -r name
    do
      [[ -n "${name}" ]] || continue
      deleted_formulae_csv="${deleted_formulae_csv:+${deleted_formulae_csv},}${TAP_PREFIX}/${name}"
    done <"${deleted_formulae_file}"
  fi

  local changed_style_files_json="[]"
  if [[ -s "${style_files_file}" ]]
  then
    changed_style_files_json="$(jq -c -R -s 'split("\n") | map(select(length > 0))' "${style_files_file}")"
  fi

  local include_macos="false"
  if [[ "${event_name}" = "workflow_dispatch" && "${input_include_macos}" = "true" ]]
  then
    include_macos="true"
  elif [[ "${event_name}" = "pull_request" ]] &&
       jq -e --arg lbl "${MACOS_BOTTLE_LABEL}" 'any(.[]; . == $lbl)' <<<"${pr_labels_json}" >/dev/null
  then
    include_macos="true"
  fi

  local matrix_oses_json="${LINUX_MATRIX_OSES_JSON}"
  if [[ "${include_macos}" = "true" ]]
  then
    matrix_oses_json="${ALL_MATRIX_OSES_JSON}"
  fi

  local is_push="false"
  if [[ "${event_name}" = "push" ]]
  then
    is_push="true"
  fi

  local run_brew_style="false"
  local run_brew_readall="false"
  local run_brew_audit_tap="false"
  local run_ast_grep="false"
  local run_bats_lint="false"
  local run_provenance_bats="false"
  local run_cask_bats="false"
  local run_installer_bats_standalone="false"
  local run_readme_check="false"
  local run_tap_docs_check="false"
  local run_lock_check="false"
  local require_lockfile="false"

  local touched_formula_or_cask="false"
  local touched_ast_grep="false"
  local touched_tests="false"
  local touched_provenance="false"
  local touched_cask_bats="false"
  local touched_installer="false"
  local touched_readme="false"
  local touched_tap_docs="false"
  local touched_lock="false"

  while IFS= read -r path
  do
    [[ -n "${path}" ]] || continue
    case "${path}" in
      Formula/*)
        touched_formula_or_cask="true"
        touched_ast_grep="true"
        touched_lock="true"
        ;;
      Casks/*)
        touched_formula_or_cask="true"
        touched_ast_grep="true"
        touched_tap_docs="true"
        ;;
      rules/* | rule-tests/* | sgconfig.yml)
        touched_ast_grep="true"
        ;;
      scripts/*)
        touched_ast_grep="true"
        ;;
      tests/*)
        touched_ast_grep="true"
        touched_tests="true"
        ;;
      .github/workflows/*)
        touched_ast_grep="true"
        touched_provenance="true"
        ;;
      versions/*)
        touched_lock="true"
        ;;
      README.md)
        touched_readme="true"
        touched_tap_docs="true"
        ;;
      ABOUT.md)
        touched_tap_docs="true"
        ;;
      *) ;;
    esac

    case "${path}" in
      Casks/* | tests/cask_postflight_defaults.bats)
        touched_cask_bats="true"
        ;;
      *) ;;
    esac

    case "${path}" in
      scripts/verify-provenance.sh | scripts/update-readme-bottles.sh | scripts/update-tap-docs.sh | \
        scripts/check-aitools-lock.sh | scripts/autobump.sh | scripts/install-agent-skills.sh | \
        scripts/lib/* | scripts/ci/* | \
        tests/verify_provenance.bats | tests/ci_workflow_plan.bats | tests/update_tap_docs.bats | \
        tests/aitools_lock.bats | tests/install_agent_skills_multitool.bats | \
        tests/helpers/provenance_helper.bash | Formula/*.rb)
        touched_provenance="true"
        ;;
      *) ;;
    esac

    case "${path}" in
      scripts/check-aitools-lock.sh | scripts/autobump.sh | scripts/lib/*)
        touched_lock="true"
        ;;
      *) ;;
    esac

    case "${path}" in
      scripts/update-tap-docs.sh | scripts/update-readme-bottles.sh | scripts/ci/verify-patch-policy.sh)
        touched_tap_docs="true"
        ;;
      *) ;;
    esac

    case "${path}" in
      scripts/install-agent-skills.sh | tests/integration_agent_install.bats | tests/helpers/agent_install_helper.bash)
        touched_installer="true"
        ;;
      *) ;;
    esac
  done <"${all_changed_file}"

  if [[ "${is_push}" = "true" || "${changed_style_files_json}" != "[]" ]]
  then
    run_brew_style="true"
  fi
  if [[ "${is_push}" = "true" || "${touched_formula_or_cask}" = "true" ]]
  then
    run_brew_readall="true"
  fi
  if [[ "${is_push}" = "true" ]]
  then
    run_brew_audit_tap="true"
  fi
  if [[ "${is_push}" = "true" || "${touched_ast_grep}" = "true" ]]
  then
    run_ast_grep="true"
  fi
  if [[ "${is_push}" = "true" || "${touched_tests}" = "true" ]]
  then
    run_bats_lint="true"
  fi
  if [[ "${is_push}" = "true" || "${touched_provenance}" = "true" ]]
  then
    run_provenance_bats="true"
  fi
  if [[ "${is_push}" = "true" || "${touched_cask_bats}" = "true" ]]
  then
    run_cask_bats="true"
  fi
  if [[ "${is_push}" != "true" && "${touched_installer}" = "true" ]] &&
     ! file_has_line "ripwire" "${changed_formulae_file}"
  then
    run_installer_bats_standalone="true"
  fi
  if [[ "${is_push}" = "true" || "${touched_readme}" = "true" ]]
  then
    run_readme_check="true"
  fi
  if [[ "${is_push}" = "true" || "${touched_tap_docs}" = "true" ]]
  then
    run_tap_docs_check="true"
  fi
  if [[ "${is_push}" = "true" || "${touched_lock}" = "true" ]]
  then
    run_lock_check="true"
  fi
  if [[ -f "versions/aitools-lock.json" ]] || file_has_line "versions/aitools-lock.json" "${deleted_file}"
  then
    require_lockfile="true"
  fi

  local needs_homebrew_in_lint="false"
  if [[ "${run_brew_style}" = "true" ||
     "${run_brew_readall}" = "true" ||
     "${run_brew_audit_tap}" = "true" ||
     "${run_ast_grep}" = "true" ||
     "${run_bats_lint}" = "true" ||
     "${run_provenance_bats}" = "true" ||
     "${run_cask_bats}" = "true" ||
     "${run_installer_bats_standalone}" = "true" ]]
  then
    needs_homebrew_in_lint="true"
  fi

  local run_lint_job="false"
  if [[ "${needs_homebrew_in_lint}" = "true" ||
     "${run_readme_check}" = "true" ||
     "${run_tap_docs_check}" = "true" ||
     "${run_lock_check}" = "true" ]]
  then
    run_lint_job="true"
  fi

  {
    printf 'shards_json=%s\n' "${shards_json}"
    printf 'shard_count=%d\n' "${shard_count}"
    printf 'has_formulae=%s\n' "${has_formulae}"
    printf 'use_merge=%s\n' "${use_merge}"
    printf 'include_macos=%s\n' "${include_macos}"
    printf 'matrix_oses_json=%s\n' "${matrix_oses_json}"
    printf 'deleted_formulae=%s\n' "${deleted_formulae_csv}"
    printf 'has_intra_tap_runtime_deps=%s\n' "${has_intra_tap_runtime_deps}"
    printf 'changed_style_files_json=%s\n' "${changed_style_files_json}"
    printf 'run_brew_style=%s\n' "${run_brew_style}"
    printf 'run_brew_readall=%s\n' "${run_brew_readall}"
    printf 'run_brew_audit_tap=%s\n' "${run_brew_audit_tap}"
    printf 'run_ast_grep=%s\n' "${run_ast_grep}"
    printf 'run_bats_lint=%s\n' "${run_bats_lint}"
    printf 'run_provenance_bats=%s\n' "${run_provenance_bats}"
    printf 'run_cask_bats=%s\n' "${run_cask_bats}"
    printf 'run_installer_bats_standalone=%s\n' "${run_installer_bats_standalone}"
    printf 'run_readme_check=%s\n' "${run_readme_check}"
    printf 'run_tap_docs_check=%s\n' "${run_tap_docs_check}"
    printf 'run_lock_check=%s\n' "${run_lock_check}"
    printf 'require_lockfile=%s\n' "${require_lockfile}"
    printf 'run_lint_job=%s\n' "${run_lint_job}"
    printf 'needs_homebrew_in_lint=%s\n' "${needs_homebrew_in_lint}"
  } >>"${github_output}"
}

main "$@"
