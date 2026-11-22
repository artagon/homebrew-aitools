#!/usr/bin/env bash
# Deterministically render or verify the complete Formula & Cask inventories and
# live tool-count badges in README.md and ABOUT.md from Formula/*.rb and Casks/*.rb.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland; requires awk, cmp, sort.
# Usage:
#   ./scripts/update-tap-docs.sh                          # update README.md and ABOUT.md atomically
#   ./scripts/update-tap-docs.sh --check                  # exit 0 if both are up to date, 1 if stale
#   ./scripts/update-tap-docs.sh --check --readme-only    # verify README.md only
#   ./scripts/update-tap-docs.sh --check --about-only     # verify ABOUT.md only
#   ./scripts/update-tap-docs.sh --stdout                 # print generated blocks
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="${TAP_DOCS_REPO_ROOT:-$(cd "${script_dir}/.." && pwd -P)}"
readme_path="${TAP_DOCS_README_FILE:-${repo_root}/README.md}"
about_path="${TAP_DOCS_ABOUT_FILE:-${repo_root}/ABOUT.md}"
readonly POLICY_HELPER="${script_dir}/ci/verify-patch-policy.sh"
readonly FORMULA_DIR="${repo_root}/Formula"
readonly CASK_DIR="${repo_root}/Casks"

# shellcheck source=scripts/ci/common.sh
source "${script_dir}/ci/common.sh"

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

die() {
  printf 'update-tap-docs: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: update-tap-docs.sh [--check | --stdout] [--readme-only | --about-only]
       update-tap-docs.sh --help
EOF
  exit 2
}

mode="write"
scope="all"
while [[ "$#" -gt 0 ]]
do
  case "$1" in
    --check)
      [[ "${mode}" = "write" ]] || usage
      mode="check"
      ;;
    --stdout)
      [[ "${mode}" = "write" ]] || usage
      mode="stdout"
      ;;
    --readme-only)
      [[ "${scope}" = "all" ]] || usage
      scope="readme"
      ;;
    --about-only)
      [[ "${scope}" = "all" ]] || usage
      scope="about"
      ;;
    -h | --help)
      cat <<'EOF'
Usage: update-tap-docs.sh [--check | --stdout] [--readme-only | --about-only]
       update-tap-docs.sh --help
EOF
      exit 0
      ;;
    *)
      usage
      ;;
  esac
  shift
done

[[ -f "${POLICY_HELPER}" ]] || die "Missing helper script: ${POLICY_HELPER}"

escape_md_cell() {
  local raw="$1"
  awk -v s="${raw}" '
    BEGIN {
      gsub(/\|/, "\\|", s)
      print s
    }
  '
}

format_homepage_link() {
  local url="$1"
  local label=""
  local gh_re='^https?://github\.com/([^/]+/[^/]+)/?$'
  if [[ "${url}" =~ ${gh_re} ]]
  then
    label="${BASH_REMATCH[1]}"
  else
    label="${url#https://}"
    label="${label#http://}"
    label="${label%/}"
  fi
  label="$(escape_md_cell "${label}")"
  printf '[%s](%s)' "${label}" "${url}"
}

normalize_license() {
  local raw="$1"
  local quoted_re='^"([^"]+)"$'
  local compound_re='^(any_of|all_of):[[:space:]]*\[(.+)\]$'
  local op="" list="" item="" joined="" sep="" dq='"'

  if [[ "${raw}" = ":cannot_represent" ]]
  then
    # shellcheck disable=SC2016
    printf 'Custom (`LICENSE`)'
    return 0
  fi

  if [[ "${raw}" =~ ${quoted_re} ]]
  then
    # shellcheck disable=SC2016
    printf '`%s`' "$(escape_md_cell "${BASH_REMATCH[1]}")"
    return 0
  fi

  if [[ "${raw}" =~ ${compound_re} ]]
  then
    if [[ "${BASH_REMATCH[1]}" = "any_of" ]]
    then
      op=" OR "
    else
      op=" AND "
    fi
    list="${BASH_REMATCH[2]}"
    while [[ "${list}" =~ \"([^\"]+)\" ]]
    do
      item="${BASH_REMATCH[1]}"
      joined="${joined}${sep}${item}"
      sep="${op}"
      list="${list#*"${dq}${item}${dq}"}"
    done
    if [[ -n "${joined}" ]]
    then
      # shellcheck disable=SC2016
      printf '`%s`' "$(escape_md_cell "${joined}")"
      return 0
    fi
  fi

  # shellcheck disable=SC2016
  printf '`%s`' "$(escape_md_cell "${raw}")"
}

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
    local scoped_ver_re='(@|%40)([vV]?[0-9][0-9A-Za-z.+_-]*)$'
    local prefixed_ver_re='^[A-Za-z][A-Za-z0-9._-]*-[vV]([0-9][0-9A-Za-z.+_-]*)$'
    local plain_ver_re='^[vV]?[0-9]'
    if [[ "${tag_part}" =~ ${scoped_ver_re} ]]
    then
      tag_part="${BASH_REMATCH[2]}"
    elif [[ "${tag_part}" == "${formula}-"* ]]
    then
      tag_part="${tag_part#"${formula}-"}"
    elif [[ ! "${tag_part}" =~ ${plain_ver_re} ]] && [[ "${tag_part}" =~ ${prefixed_ver_re} ]]
    then
      tag_part="${BASH_REMATCH[1]}"
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

format_bottle_tags() {
  local raw_tags="$1"
  if [[ -z "${raw_tags}" ]]
  then
    printf 'source'
    return 0
  fi

  local rank_file="${work_dir}/bottle-ranks.tsv"
  : >"${rank_file}"
  local tag="" rank=""
  for tag in ${raw_tags}
  do
    rank="$(ci::bottle_tag_sort_rank "${tag}")"
    printf '%s\t%s\n' "${rank}" "${tag}" >>"${rank_file}"
  done

  local formatted="" sep=""
  while IFS=$'\t' read -r _ tag
  do
    [[ -n "${tag}" ]] || continue
    formatted="${formatted}${sep}\`${tag}\`"
    sep=" · "
  done < <(LC_ALL=C sort -u -t $'\t' -k1,1n -k2,2 "${rank_file}")

  printf '%s' "${formatted}"
}

plural_word() {
  local count="$1" singular="$2" plural="$3"
  if [[ "${count}" -eq 1 ]]
  then
    printf '%s' "${singular}"
  else
    printf '%s' "${plural}"
  fi
}

parse_formula_file() {
  local rb_file="$1"
  local formula=""
  formula="$(basename "${rb_file}" .rb)"
  ci::require_formula_name "${formula}" "formula filename"

  local in_skip=0 skip_indent=""
  local in_bottle=0 bottle_indent=""
  local desc="" homepage="" explicit_version="" revision="0" primary_url="" license_raw="" bottle_tags=""
  local line=""

  local stop_re='^  (def (install|caveats|post_install)|test do)$|^__END__$'
  local skip_start_re='^([[:space:]]*)(livecheck|resource "[^"]+"|fails_with[^d]+|head)[[:space:]]+do$'
  local bottle_start_re='^([[:space:]]*)bottle do$'
  local desc_re='^  desc "([^"]+)"$'
  local homepage_re='^  homepage "([^"]+)"$'
  local version_re='^  version "([^"]+)"$'
  local revision_re='^  revision ([0-9]+)$'
  local license_re='^  license (.+)$'
  local url_re='^[[:space:]]*url "([^"]+)"'
  local bottle_tag_re='([a-z0-9_]+):[[:space:]]+"[0-9a-f]{64}"'

  while IFS= read -r line || [[ -n "${line}" ]]
  do
    if [[ "${line}" =~ ${stop_re} ]]
    then
      break
    fi

    if [[ "${in_skip}" -eq 1 ]]
    then
      if [[ "${line}" == "${skip_indent}end" ]]
      then
        in_skip=0
        skip_indent=""
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
      if [[ "${line}" =~ ^[[:space:]]*sha256[[:space:]] ]] && [[ "${line}" =~ ${bottle_tag_re} ]]
      then
        bottle_tags="${bottle_tags:+${bottle_tags} }${BASH_REMATCH[1]}"
      fi
      continue
    fi

    if [[ "${line}" =~ ${skip_start_re} ]]
    then
      in_skip=1
      skip_indent="${BASH_REMATCH[1]}"
      continue
    fi

    if [[ "${line}" =~ ${bottle_start_re} ]]
    then
      in_bottle=1
      bottle_indent="${BASH_REMATCH[1]}"
      continue
    fi

    if [[ -z "${desc}" && "${line}" =~ ${desc_re} ]]
    then
      desc="${BASH_REMATCH[1]}"
    elif [[ -z "${homepage}" && "${line}" =~ ${homepage_re} ]]
    then
      homepage="${BASH_REMATCH[1]}"
    elif [[ -z "${explicit_version}" && "${line}" =~ ${version_re} ]]
    then
      explicit_version="${BASH_REMATCH[1]}"
    elif [[ "${line}" =~ ${revision_re} ]]
    then
      revision="${BASH_REMATCH[1]}"
    elif [[ -z "${license_raw}" && "${line}" =~ ${license_re} ]]
    then
      license_raw="${BASH_REMATCH[1]}"
    elif [[ -z "${primary_url}" && "${line}" =~ ${url_re} ]]
    then
      primary_url="${BASH_REMATCH[1]}"
    fi
  done <"${rb_file}"

  local version=""
  if [[ -n "${explicit_version}" ]]
  then
    version="${explicit_version}"
  elif [[ -n "${primary_url}" ]]
  then
    version="$(extract_version_from_url "${formula}" "${primary_url}" || true)"
  fi

  [[ -n "${version}" ]] || die "Could not determine version for ${rb_file}"
  [[ -n "${desc}" ]] || die "Missing desc in ${rb_file}"
  [[ -n "${homepage}" ]] || die "Missing homepage in ${rb_file}"

  local pkg_version="${version}"
  if [[ "${revision}" -gt 0 ]]
  then
    pkg_version="${version}_${revision}"
  fi

  local license_md="—"
  if [[ -n "${license_raw}" ]]
  then
    license_md="$(normalize_license "${license_raw}")"
  fi

  local bottles_md=""
  bottles_md="$(format_bottle_tags "${bottle_tags}")"
  local is_bottled="0"
  if [[ -n "${bottle_tags}" ]]
  then
    is_bottled="1"
  fi

  local hp_md="" desc_md=""
  hp_md="$(format_homepage_link "${homepage}")"
  desc_md="$(escape_md_cell "${desc}")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${formula}" "${pkg_version}" "${license_md}" "${bottles_md}" "${is_bottled}" "${hp_md}" "${desc_md}"
}

parse_cask_file() {
  local rb_file="$1"
  local cask=""
  cask="$(basename "${rb_file}" .rb)"
  ci::require_formula_name "${cask}" "cask filename"

  local in_skip=0 skip_indent=""
  local desc="" homepage="" version=""
  local line=""

  local stop_re='^  (postflight_steps|caveats|zap|uninstall|app |binary |artifact |suite |pkg |installer )|^__END__$'
  local skip_start_re='^([[:space:]]*)(livecheck|on_arm|on_intel)[[:space:]]+do$'
  local desc_re='^  desc "([^"]+)"$'
  local homepage_re='^  homepage "([^"]+)"$'
  local version_re='^  version "([^"]+)"$'

  while IFS= read -r line || [[ -n "${line}" ]]
  do
    if [[ "${line}" =~ ${stop_re} ]]
    then
      break
    fi

    if [[ "${in_skip}" -eq 1 ]]
    then
      if [[ "${line}" == "${skip_indent}end" ]]
      then
        in_skip=0
        skip_indent=""
      fi
      continue
    fi

    if [[ "${line}" =~ ${skip_start_re} ]]
    then
      in_skip=1
      skip_indent="${BASH_REMATCH[1]}"
      continue
    fi

    if [[ -z "${desc}" && "${line}" =~ ${desc_re} ]]
    then
      desc="${BASH_REMATCH[1]}"
    elif [[ -z "${homepage}" && "${line}" =~ ${homepage_re} ]]
    then
      homepage="${BASH_REMATCH[1]}"
    elif [[ -z "${version}" && "${line}" =~ ${version_re} ]]
    then
      version="${BASH_REMATCH[1]}"
    fi
  done <"${rb_file}"

  [[ -n "${version}" ]] || die "Missing version in ${rb_file}"
  [[ -n "${desc}" ]] || die "Missing desc in ${rb_file}"
  [[ -n "${homepage}" ]] || die "Missing homepage in ${rb_file}"

  local hp_md="" desc_md=""
  hp_md="$(format_homepage_link "${homepage}")"
  desc_md="$(escape_md_cell "${desc}")"

  printf '%s\t%s\t%s\t%s\n' "${cask}" "${version}" "${hp_md}" "${desc_md}"
}

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/update-tap-docs.XXXXXX")"
formulae_tsv="${work_dir}/formulae.tsv"
casks_tsv="${work_dir}/casks.tsv"
: >"${formulae_tsv}"
: >"${casks_tsv}"

formula_count=0
bottled_count=0
source_count=0
cask_count=0

if [[ -d "${FORMULA_DIR}" ]]
then
  shopt -s nullglob
  formula_files=("${FORMULA_DIR}"/*.rb)
  shopt -u nullglob
  if [[ "${#formula_files[@]}" -gt 0 ]]
  then
    sorted_formula_list="${work_dir}/formula-files.txt"
    printf '%s\n' "${formula_files[@]}" | LC_ALL=C sort >"${sorted_formula_list}"
    while IFS= read -r rb_file
    do
      [[ -f "${rb_file}" ]] || continue
      row="$(parse_formula_file "${rb_file}")"
      printf '%s\n' "${row}" >>"${formulae_tsv}"
      formula_count=$((formula_count + 1))
      is_bottled="$(printf '%s\n' "${row}" | awk -F '\t' '{ print $5 }')"
      if [[ "${is_bottled}" = "1" ]]
      then
        bottled_count=$((bottled_count + 1))
      else
        source_count=$((source_count + 1))
      fi
    done <"${sorted_formula_list}"
  fi
fi

if [[ -d "${CASK_DIR}" ]]
then
  shopt -s nullglob
  cask_files=("${CASK_DIR}"/*.rb)
  shopt -u nullglob
  if [[ "${#cask_files[@]}" -gt 0 ]]
  then
    sorted_cask_list="${work_dir}/cask-files.txt"
    printf '%s\n' "${cask_files[@]}" | LC_ALL=C sort >"${sorted_cask_list}"
    while IFS= read -r rb_file
    do
      [[ -f "${rb_file}" ]] || continue
      parse_cask_file "${rb_file}" >>"${casks_tsv}"
      cask_count=$((cask_count + 1))
    done <"${sorted_cask_list}"
  fi
fi

total_count=$((formula_count + cask_count))
formula_word="$(plural_word "${formula_count}" "formula" "formulae")"
cask_word="$(plural_word "${cask_count}" "cask" "casks")"
tool_word="$(plural_word "${total_count}" "tool" "tools")"

render_readme_badges() {
  printf '%s\n' "<!-- BEGIN TAP_BADGES -->"
  printf '%s\n' "<!-- Auto-generated from Formula/*.rb and Casks/*.rb by scripts/update-tap-docs.sh (and refreshed automatically by publish.yml). Do not edit manually. -->"
  printf '[![Formulae: %d](https://img.shields.io/badge/formulae-%d-8250df)](#complete-formula--cask-inventory)\n' \
    "${formula_count}" "${formula_count}"
  printf '[![Casks: %d](https://img.shields.io/badge/casks-%d-bf3989)](#complete-formula--cask-inventory)\n' \
    "${cask_count}" "${cask_count}"
  printf '%s\n' "<!-- END TAP_BADGES -->"
}

render_readme_inventory() {
  local name="" pkg_ver="" lic="" bots="" is_bot="" hp="" desc=""
  printf '%s\n' "<!-- BEGIN TAP_INVENTORY -->"
  printf '%s\n' "<!-- Auto-generated from Formula/*.rb and Casks/*.rb by scripts/update-tap-docs.sh (and refreshed automatically by publish.yml). Do not edit manually. -->"
  printf '\n'
  printf 'Total packaged %s: **%d** (**%d** %s: **%d** bottled, **%d** source-only; **%d** macOS %s).\n' \
    "${tool_word}" "${total_count}" "${formula_count}" "${formula_word}" "${bottled_count}" "${source_count}" "${cask_count}" "${cask_word}"
  printf '\n'
  printf '### Formulae (%d)\n' "${formula_count}"
  printf '\n'
  printf '| Formula | Version | License | Bottles | Description |\n'
  printf '| :--- | :--- | :--- | :--- | :--- |\n'
  while IFS=$'\t' read -r name pkg_ver lic bots is_bot hp desc
  do
    [[ -n "${name}" ]] || continue
    : "${is_bot}"
    # shellcheck disable=SC2016
    printf '| [`%s`](Formula/%s.rb) | `%s` | %s | %s | %s — %s |\n' \
      "${name}" "${name}" "${pkg_ver}" "${lic}" "${bots}" "${hp}" "${desc}"
  done <"${formulae_tsv}"

  if [[ "${cask_count}" -gt 0 ]]
  then
    printf '\n'
    printf '### macOS Casks (%d)\n' "${cask_count}"
    printf '\n'
    printf '| Cask | Version | Description |\n'
    printf '| :--- | :--- | :--- |\n'
    while IFS=$'\t' read -r name pkg_ver hp desc
    do
      [[ -n "${name}" ]] || continue
      # shellcheck disable=SC2016
      printf '| [`%s`](Casks/%s.rb) | `%s` | %s — %s |\n' \
        "${name}" "${name}" "${pkg_ver}" "${hp}" "${desc}"
    done <"${casks_tsv}"
  fi
  printf '%s\n' "<!-- END TAP_INVENTORY -->"
}

render_about_inventory() {
  local name="" pkg_ver="" lic="" bots="" is_bot="" hp="" desc=""
  printf '%s\n' "<!-- BEGIN ABOUT_INVENTORY -->"
  printf '%s\n' "<!-- Auto-generated from Formula/*.rb and Casks/*.rb by scripts/update-tap-docs.sh (and refreshed automatically by publish.yml). Do not edit manually. -->"
  printf '\n'
  printf 'This tap currently packages **%d** %s: **%d** %s (**%d** bottled, **%d** source-only) and **%d** macOS %s.\n' \
    "${total_count}" "${tool_word}" "${formula_count}" "${formula_word}" "${bottled_count}" "${source_count}" "${cask_count}" "${cask_word}"
  printf '\n'
  printf '| Tool | Kind | Version | License | Bottles | Summary |\n'
  printf '| :--- | :--- | :--- | :--- | :--- | :--- |\n'
  while IFS=$'\t' read -r name pkg_ver lic bots is_bot hp desc
  do
    [[ -n "${name}" ]] || continue
    : "${is_bot}"
    # shellcheck disable=SC2016
    printf '| [`%s`](Formula/%s.rb) | Formula | `%s` | %s | %s | %s — %s |\n' \
      "${name}" "${name}" "${pkg_ver}" "${lic}" "${bots}" "${hp}" "${desc}"
  done <"${formulae_tsv}"
  while IFS=$'\t' read -r name pkg_ver hp desc
  do
    [[ -n "${name}" ]] || continue
    # shellcheck disable=SC2016
    printf '| [`%s`](Casks/%s.rb) | Cask | `%s` | — | macOS cask | %s — %s |\n' \
      "${name}" "${name}" "${pkg_ver}" "${hp}" "${desc}"
  done <"${casks_tsv}"
  printf '%s\n' "<!-- END ABOUT_INVENTORY -->"
}

if [[ "${mode}" = "stdout" ]]
then
  if [[ "${scope}" = "all" || "${scope}" = "readme" ]]
  then
    render_readme_badges
    printf '\n'
    render_readme_inventory
  fi
  if [[ "${scope}" = "all" ]]
  then
    printf '\n'
  fi
  if [[ "${scope}" = "all" || "${scope}" = "about" ]]
  then
    render_about_inventory
  fi
  exit 0
fi

apply_or_check_file() {
  local target_path="$1"
  local candidate_path="$2"
  local label="$3"
  local target_dir="" target_base="" tmp_dest=""

  if [[ "${mode}" = "check" ]]
  then
    if ! cmp -s "${target_path}" "${candidate_path}"
    then
      die "${label} (${target_path}) is out of date; run ./scripts/update-tap-docs.sh"
    fi
    return 0
  fi

  if ! cmp -s "${target_path}" "${candidate_path}"
  then
    target_dir="$(cd "$(dirname "${target_path}")" && pwd -P)"
    target_base="$(basename "${target_path}")"
    tmp_dest="$(mktemp "${target_dir}/.${target_base}.tmp.XXXXXX")"
    cp -- "${candidate_path}" "${tmp_dest}"
    chmod 0644 "${tmp_dest}"
    mv -f -- "${tmp_dest}" "${target_path}"
  fi
}

if [[ "${scope}" = "all" || "${scope}" = "readme" ]]
then
  [[ -f "${readme_path}" ]] || die "README not found: ${readme_path}"
  badges_block="${work_dir}/tap-badges.md"
  inv_block="${work_dir}/tap-inventory.md"
  readme_step1="${work_dir}/readme-step1.md"
  readme_step2="${work_dir}/readme-step2.md"

  render_readme_badges >"${badges_block}"
  render_readme_inventory >"${inv_block}"

  bash "${POLICY_HELPER}" replace-block "${readme_path}" "${readme_step1}" "${badges_block}" "TAP_BADGES" ||
    die "Failed to update TAP_BADGES in ${readme_path}"
  bash "${POLICY_HELPER}" replace-block "${readme_step1}" "${readme_step2}" "${inv_block}" "TAP_INVENTORY" ||
    die "Failed to update TAP_INVENTORY in ${readme_path}"

  apply_or_check_file "${readme_path}" "${readme_step2}" "README tap inventory"
fi

if [[ "${scope}" = "all" || "${scope}" = "about" ]]
then
  [[ -f "${about_path}" ]] || die "ABOUT not found: ${about_path}"
  about_block="${work_dir}/about-inventory.md"
  about_out="${work_dir}/about-out.md"

  render_about_inventory >"${about_block}"
  bash "${POLICY_HELPER}" replace-block "${about_path}" "${about_out}" "${about_block}" "ABOUT_INVENTORY" ||
    die "Failed to update ABOUT_INVENTORY in ${about_path}"

  apply_or_check_file "${about_path}" "${about_out}" "ABOUT tap inventory"
fi
