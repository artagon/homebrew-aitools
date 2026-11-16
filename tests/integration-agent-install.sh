#!/usr/bin/env bash
# Run real Ripwire agent-skill installer integrations across Bash 3.2 and Bash 5+.
# No live user or agent state is read or modified; see tests/README.md.
#
# Target contract: Bash 3.2+ executable; macOS BSD + Linux GNU userland;
# requires awk, cmp, cp, env, find, grep, jq, mktemp, readlink, ruby, sort.
# shellcheck disable=SC2310,SC2312

set -euo pipefail
export LC_ALL=C

readonly INSTALLER_SHA256="f1bebd22a59539d92f061bbc3609e5a408f193209f905f60781eb2c533bf9e96"
readonly TARGET_NAMES=(claude codex agy kimi grok copilot shared)
readonly ISOLATED_COMMANDS=(basename dirname mkdir grep rm ln mktemp mv chmod cat jq)

pkgshare="/opt/homebrew/opt/ripwire/share/ripwire"
bash32="/bin/bash"
modern_bash="/opt/homebrew/bin/bash"
receipt_path=""
regressions_only=0

usage() {
  cat <<'EOF'
Usage: integration-agent-install.sh --receipt <path> [options]

Options:
  --pkgshare <dir>       Ripwire share directory (default: /opt/homebrew/opt/ripwire/share/ripwire)
  --bash32 <path>        Bash 3.2 interpreter (default: /bin/bash)
  --modern-bash <path>   Bash 5+ interpreter (default: /opt/homebrew/bin/bash)
  --receipt <path>       Output JSON receipt path (required)
  --regressions-only     Run only the 12 core regression cases
  -h, --help             Show this help message
EOF
}

while [[ "$#" -gt 0 ]]
do
  case "$1" in
    --pkgshare)
      [[ "$#" -ge 2 ]] || {
        usage >&2
        exit 2
      }
      pkgshare="$2"
      shift 2
      ;;
    --bash32)
      [[ "$#" -ge 2 ]] || {
        usage >&2
        exit 2
      }
      bash32="$2"
      shift 2
      ;;
    --modern-bash)
      [[ "$#" -ge 2 ]] || {
        usage >&2
        exit 2
      }
      modern_bash="$2"
      shift 2
      ;;
    --receipt)
      [[ "$#" -ge 2 ]] || {
        usage >&2
        exit 2
      }
      receipt_path="$2"
      shift 2
      ;;
    --regressions-only)
      regressions_only=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${receipt_path}" ]]
then
  printf 'Missing required --receipt <path>\n' >&2
  usage >&2
  exit 2
fi

sha256_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1
  then
    shasum -a 256 -- "${path}" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1
  then
    sha256sum -- "${path}" | awk '{ print $1 }'
  else
    openssl dgst -sha256 "${path}" | awk '{ print $NF }'
  fi
}

write_prereq_error() {
  local msg="$1"
  local out_dir=""
  out_dir="$(dirname "${receipt_path}")"
  mkdir -p "${out_dir}"
  jq -n --arg err "${msg}" '{prerequisite_error: $err, failed: 1}' >"${receipt_path}"
  printf 'Receipt: %s\n' "${receipt_path}"
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  printf 'Required command missing: jq\n' >&2
  exit 1
}

ENV_BIN="$(command -v env || true)"
[[ -n "${ENV_BIN}" ]] || write_prereq_error "Required command missing: env"
RUBY_BIN="$(command -v ruby || true)"
[[ -n "${RUBY_BIN}" ]] || write_prereq_error "Ruby is required to evaluate the formula wrapper"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/.." && pwd -P)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/ripwire-integration.XXXXXX")"
scratch="$(cd "${scratch}" && pwd -P)"

formula_src="${repo_root}/Formula/ripwire.rb"
standalone_src="${repo_root}/scripts/install-agent-skills.sh"
[[ -f "${formula_src}" ]] || write_prereq_error "Missing ${formula_src}"
[[ -f "${standalone_src}" ]] || write_prereq_error "Missing ${standalone_src}"

formula_sha="$(sha256_file "${formula_src}")"
standalone_sha="$(sha256_file "${standalone_src}")"

formula_snapshot="${scratch}/ripwire.rb"
standalone_snapshot="${scratch}/install-agent-skills.sh"
cp "${formula_src}" "${formula_snapshot}"
cp "${standalone_src}" "${standalone_snapshot}"

if [[ "$(sha256_file "${formula_snapshot}")" != "${formula_sha}" ]] ||
   [[ "$(sha256_file "${standalone_snapshot}")" != "${standalone_sha}" ]]
then
  write_prereq_error "Source changed while creating test snapshot; rerun"
fi

if [[ ! -d "${pkgshare}" ]]
then
  write_prereq_error "Requires the unmodified Ripwire 0.6.9 bundled installer"
fi
orig_pkgshare="$(cd "${pkgshare}" && pwd -P)"
installer_file="${orig_pkgshare}/skills/install.sh"
if [[ ! -f "${installer_file}" ]] || [[ "$(sha256_file "${installer_file}")" != "${INSTALLER_SHA256}" ]]
then
  write_prereq_error "Requires the unmodified Ripwire 0.6.9 bundled installer"
fi

payload_dir="${scratch}/payload"
cp -RL "${orig_pkgshare}" "${payload_dir}"
payload_dir="$(cd "${payload_dir}" && pwd -P)"

expected_default_file="${scratch}/expected-default.txt"
expected_contrib_file="${scratch}/expected-contrib.txt"
: >"${expected_default_file}"
: >"${expected_contrib_file}"

for skill_md in "${payload_dir}/skills"/ripwire-*/SKILL.md
do
  [[ -f "${skill_md}" ]] || continue
  skill_name="$(basename "$(dirname "${skill_md}")")"
  printf '%s\n' "${skill_name}" >>"${expected_contrib_file}"
  if ! grep -Eq '^audience: contributor$' "${skill_md}"
  then
    printf '%s\n' "${skill_name}" >>"${expected_default_file}"
  fi
done

sort -u "${expected_default_file}" -o "${expected_default_file}"
sort -u "${expected_contrib_file}" -o "${expected_contrib_file}"

default_count="$(wc -l <"${expected_default_file}" | awk '{ print $1 }')"
contrib_count="$(wc -l <"${expected_contrib_file}" | awk '{ print $1 }')"
if [[ "${default_count}" -ne 16 || "${contrib_count}" -ne 17 ]]
then
  write_prereq_error "Unexpected pinned payload skill set"
fi

wrapper_snapshot="${scratch}/ripwire-agent-install"
# Evaluate the exact Formula/ripwire.rb heredoc via Ruby without translating shell text.
if ! "${RUBY_BIN}" -EUTF-8:UTF-8 -e '
   source = File.read(ARGV[0])
   match = source.match(/\(bin\/"ripwire-agent-install"\)\.write (<<~SHELL\n.*?^    SHELL\n)/m)
   abort "Cannot locate formula wrapper heredoc" unless match
   opt_pkgshare = ARGV[1]
   print eval(match[1], binding, ARGV[0])
   ' "${formula_snapshot}" "${payload_dir}" >"${wrapper_snapshot}"
then
  write_prereq_error "Failed to evaluate Formula/ripwire.rb wrapper heredoc"
fi

[[ -x "${bash32}" ]] || write_prereq_error "--bash32 is not executable: ${bash32}"
[[ -x "${modern_bash}" ]] || write_prereq_error "--modern-bash is not executable: ${modern_bash}"

bash32_ver="$("${bash32}" --version | awk 'NR == 1 { print; exit }')"
modern_ver="$("${modern_bash}" --version | awk 'NR == 1 { print; exit }')"
[[ "${bash32_ver}" =~ version\ 3\.2\. ]] || write_prereq_error "--bash32 must identify Bash 3.2"
[[ "${modern_ver}" =~ version\ [5-9]\. ]] || write_prereq_error "--modern-bash must identify Bash 5 or newer"

cmd_template_dir="${scratch}/cmd-bin-template"
mkdir -p "${cmd_template_dir}"
for cmd_name in "${ISOLATED_COMMANDS[@]}"
do
  resolved_cmd="$(command -v "${cmd_name}" || true)"
  [[ -n "${resolved_cmd}" ]] || write_prereq_error "Required command missing: ${cmd_name}"
  ln -s "${resolved_cmd}" "${cmd_template_dir}/${cmd_name}"
done

target_relpath() {
  case "$1" in
    claude) printf '%s\n' ".claude/skills" ;;
    codex | shared) printf '%s\n' ".agents/skills" ;;
    agy) printf '%s\n' ".gemini/antigravity-cli/skills" ;;
    kimi) printf '%s\n' ".kimi-code/skills" ;;
    grok) printf '%s\n' ".grok/skills" ;;
    copilot) printf '%s\n' ".copilot/skills" ;;
    *) return 1 ;;
  esac
}

ALL_DEST_RELPATHS=(
  ".claude/skills"
  ".agents/skills"
  ".gemini/antigravity-cli/skills"
  ".kimi-code/skills"
  ".grok/skills"
  ".copilot/skills"
)

case_fail() {
  printf '%s\n' "$*" >&2
  return 1
}

setup_case_env() {
  local shell_bin="$1"
  local label="$2"
  local root="${scratch}/${label}"
  mkdir -p "${root}/home" "${root}/bin" "${root}/tmp"
  local link=""
  for link in "${cmd_template_dir}"/*
  do
    ln -s "$(readlink "${link}")" "${root}/bin/$(basename "${link}")"
  done
  ln -s "${shell_bin}" "${root}/bin/bash"
  printf '%s\n' "${root}"
}

invoke_entry() {
  local root="$1"
  local shell_bin="$2"
  local entry_path="$3"
  local agy_override="$4"
  shift 4

  local out_file="${root}/last.out"
  local err_file="${root}/last.err"
  local -a env_args=(
    "HOME=${root}/home"
    "PATH=${root}/bin"
    "LC_ALL=C"
    "TMPDIR=${root}/tmp"
    "RIPWIRE_PKGSHARE=${payload_dir}"
  )
  if [[ -n "${agy_override}" ]]
  then
    env_args+=("AGY_SKILLS_DIR=${agy_override}")
  fi

  local rc=0
  (
    cd "${root}/home" &&
      "${ENV_BIN}" -i "${env_args[@]}" "${shell_bin}" "${entry_path}" "$@"
  ) >"${out_file}" 2>"${err_file}" || rc=$?

  if [[ "${rc}" -ne 0 ]]
  then
    case_fail "exit ${rc}: $(cat "${err_file}")"
    return 1
  fi
  cat "${out_file}"
}

snapshot_tree() {
  local dir="$1"
  local out_manifest="$2"
  : >"${out_manifest}"
  local p=""
  local rel=""
  while IFS= read -r p
  do
    [[ -z "${p}" ]] && continue
    rel="${p#"${dir}/"}"
    if [[ -L "${p}" ]]
    then
      printf 'L\t%s\t%s\n' "${rel}" "$(readlink "${p}")" >>"${out_manifest}"
    elif [[ -f "${p}" ]]
    then
      printf 'F\t%s\t%s\n' "${rel}" "$(sha256_file "${p}")" >>"${out_manifest}"
    elif [[ -d "${p}" ]]
    then
      printf 'D\t%s\n' "${rel}" >>"${out_manifest}"
    fi
  done < <(find "${dir}" -mindepth 1 -print | LC_ALL=C sort)
}

assert_no_hooks() {
  local home="$1"
  [[ ! -e "${home}/.claude/settings.json" && ! -L "${home}/.claude/settings.json" ]] ||
    {
      case_fail "unexpected Claude hooks"
      return 1
    }
  [[ ! -e "${home}/.codex/hooks.json" && ! -L "${home}/.codex/hooks.json" ]] ||
    {
      case_fail "unexpected Codex hooks"
      return 1
    }
}

verify_skills() {
  local destination="$1"
  local contributor="$2"
  local manifest="${destination}/.ripwire-manifest-v1"
  [[ -f "${manifest}" ]] || {
    case_fail "missing manifest: ${destination}"
    return 1
  }

  local first_line=""
  first_line="$(awk 'NR == 1 { print; exit }' "${manifest}")"
  [[ "${first_line}" = "version=1" ]] || {
    case_fail "manifest version"
    return 1
  }

  local expected_file="${expected_default_file}"
  if [[ "${contributor}" -eq 1 ]]
  then
    expected_file="${expected_contrib_file}"
  fi

  local tmp_actual="${scratch}/.actual-manifest.$$"
  local tmp_actual_sorted="${scratch}/.actual-manifest-sorted.$$"
  local tmp_installed="${scratch}/.installed-skills.$$"

  awk 'NR > 1 { sub(/^skill=/, ""); print }' "${manifest}" >"${tmp_actual}"
  sort "${tmp_actual}" >"${tmp_actual_sorted}"
  local raw_lines=""
  local uniq_lines=""
  raw_lines="$(wc -l <"${tmp_actual}" | awk '{ print $1 }')"
  uniq_lines="$(sort -u "${tmp_actual}" | wc -l | awk '{ print $1 }')"
  if [[ "${raw_lines}" -ne "${uniq_lines}" ]]
  then
    rm -f -- "${tmp_actual}" "${tmp_actual_sorted}" "${tmp_installed}"
    case_fail "duplicate manifest skill"
    return 1
  fi
  if ! cmp -s "${tmp_actual_sorted}" "${expected_file}"
  then
    rm -f -- "${tmp_actual}" "${tmp_actual_sorted}" "${tmp_installed}"
    case_fail "wrong manifest skill set"
    return 1
  fi

  : >"${tmp_installed}"
  local s_path=""
  for s_path in "${destination}"/ripwire-*
  do
    [[ -e "${s_path}" || -L "${s_path}" ]] || continue
    basename "${s_path}" >>"${tmp_installed}"
  done
  sort -u "${tmp_installed}" -o "${tmp_installed}"
  if ! cmp -s "${tmp_installed}" "${expected_file}"
  then
    rm -f -- "${tmp_actual}" "${tmp_actual_sorted}" "${tmp_installed}"
    case_fail "unexpected installed skill set"
    return 1
  fi

  local skill=""
  local link=""
  local resolved=""
  local loop_err=""
  while IFS= read -r skill
  do
    [[ -z "${skill}" ]] && continue
    link="${destination}/${skill}"
    if [[ ! -L "${link}" ]]
    then
      loop_err="not a symlink: ${skill}"
      break
    fi
    resolved="$(cd "${link}" 2>/dev/null && pwd -P || true)"
    if [[ "${resolved}" != "${payload_dir}/skills/${skill}" ]]
    then
      loop_err="wrong payload link: ${skill}"
      break
    fi
    if [[ ! -f "${link}/SKILL.md" ]]
    then
      loop_err="broken skill link: ${skill}"
      break
    fi
  done <"${tmp_actual}"

  rm -f -- "${tmp_actual}" "${tmp_actual_sorted}" "${tmp_installed}"
  if [[ -n "${loop_err}" ]]
  then
    case_fail "${loop_err}"
    return 1
  fi
}

run_regression_case() {
  local label="$1"
  local entry="$2"
  local shell_bin="$3"
  local kind="$4"

  local root=""
  root="$(setup_case_env "${shell_bin}" "${label}")" || return 1
  local home="${root}/home"

  case "${kind}" in
    default)
      invoke_entry "${root}" "${shell_bin}" "${entry}" "" >/dev/null || return 1
      verify_skills "${home}/.agents/skills" 0 || return 1
      ;;
    custom_agy)
      local custom="${home}/custom agy skills"
      mkdir -p "${custom}"
      snapshot_tree "${home}" "${root}/before.tree"
      local listing=""
      listing="$(invoke_entry "${root}" "${shell_bin}" "${entry}" "${custom}" --list)" || return 1
      printf '%s\n' "${listing}" | grep -Eq '^[[:space:]]*agy[[:space:]]+installed[[:space:]]+' ||
        {
          case_fail "custom AGY root not detected"
          return 1
        }
      [[ "${listing}" = *"${custom}"* ]] || {
        case_fail "custom AGY path absent from list"
        return 1
      }
      snapshot_tree "${home}" "${root}/after-list.tree"
      cmp -s "${root}/before.tree" "${root}/after-list.tree" || {
        case_fail "--list changed agent state"
        return 1
      }
      invoke_entry "${root}" "${shell_bin}" "${entry}" "${custom}" >/dev/null || return 1
      verify_skills "${custom}" 0 || return 1
      invoke_entry "${root}" "${shell_bin}" "${entry}" "${custom}" --all --contributor >/dev/null || return 1
      verify_skills "${custom}" 1 || return 1
      [[ ! -e "${home}/.gemini" ]] || {
        case_fail "custom AGY root ignored"
        return 1
      }
      assert_no_hooks "${home}" || return 1
      ;;
    shared_hook)
      mkdir -p "${home}/.agents"
      invoke_entry "${root}" "${shell_bin}" "${entry}" "" --hook >/dev/null || return 1
      [[ ! -e "${home}/.codex" ]] || {
        case_fail "shared root falsely created Codex configuration"
        return 1
      }
      [[ ! -e "${home}/.claude" ]] || {
        case_fail "shared root falsely created Claude configuration"
        return 1
      }
      verify_skills "${home}/.agents/skills" 0 || return 1
      ;;
    *)
      case_fail "unknown regression kind: ${kind}"
      return 1
      ;;
  esac
}

run_install_matrix_case() {
  local label="$1"
  local entry="$2"
  local shell_bin="$3"
  local target="$4"
  local contributor="$5"

  local root=""
  root="$(setup_case_env "${shell_bin}" "${label}")" || return 1
  local home="${root}/home"

  local -a flags=()
  local -a selected_rels=()
  if [[ "${target}" = "default" ]]
  then
    selected_rels=(".agents/skills")
  elif [[ "${target}" = "all" ]]
  then
    flags+=("--all")
    mkdir -p "${home}/.claude" "${home}/.codex" "${home}/.gemini" \
      "${home}/.kimi-code" "${home}/.grok" "${home}/.copilot"
    selected_rels=("${ALL_DEST_RELPATHS[@]}")
  else
    flags+=("--${target}")
    local rel=""
    rel="$(target_relpath "${target}")" || return 1
    selected_rels=("${rel}")
  fi

  if [[ "${contributor}" -eq 1 ]]
  then
    flags+=("--contributor")
  fi

  invoke_entry "${root}" "${shell_bin}" "${entry}" "" ${flags[@]+"${flags[@]}"} >/dev/null || return 1

  local sel=""
  for sel in "${selected_rels[@]}"
  do
    verify_skills "${home}/${sel}" "${contributor}" || return 1
  done

  local candidate=""
  local is_selected=0
  for candidate in "${ALL_DEST_RELPATHS[@]}"
  do
    is_selected=0
    for sel in "${selected_rels[@]}"
    do
      if [[ "${candidate}" = "${sel}" ]]
      then
        is_selected=1
        break
      fi
    done
    if [[ "${is_selected}" -eq 0 && -e "${home}/${candidate}" ]]
    then
      case_fail "unselected target received skills: ${candidate}"
      return 1
    fi
  done

  assert_no_hooks "${home}" || return 1

  snapshot_tree "${home}" "${root}/before.tree"
  invoke_entry "${root}" "${shell_bin}" "${entry}" "" ${flags[@]+"${flags[@]}"} >/dev/null || return 1
  snapshot_tree "${home}" "${root}/after.tree"
  cmp -s "${root}/before.tree" "${root}/after.tree" || {
    case_fail "repeat install changed installed state"
    return 1
  }

  if [[ "${contributor}" -eq 1 ]]
  then
    local -a non_contrib_flags=()
    local f=""
    for f in ${flags[@]+"${flags[@]}"}
    do
      [[ "${f}" = "--contributor" ]] && continue
      non_contrib_flags+=("${f}")
    done
    invoke_entry "${root}" "${shell_bin}" "${entry}" "" \
      ${non_contrib_flags[@]+"${non_contrib_flags[@]}"} >/dev/null || return 1
    for sel in "${selected_rels[@]}"
    do
      verify_skills "${home}/${sel}" 0 || return 1
    done
  fi
}

run_hook_install_case() {
  local label="$1"
  local entry="$2"
  local shell_bin="$3"
  local target="$4"
  local contributor="$5"

  local root=""
  root="$(setup_case_env "${shell_bin}" "${label}")" || return 1
  local home="${root}/home"

  local config_rel=".codex/hooks.json"
  local opposite_rel=".claude/settings.json"
  if [[ "${target}" = "claude" ]]
  then
    config_rel=".claude/settings.json"
    opposite_rel=".codex/hooks.json"
  fi
  local config_file="${home}/${config_rel}"
  mkdir -p "$(dirname "${config_file}")"
  cat >"${config_file}" <<'JSON'
{"existing_setting":"preserve-me","hooks":{"PreToolUse":[{"matcher":"other","hooks":[{"type":"command","command":"echo preserved"}]}]}}
JSON

  local -a flags=("--${target}" "--hook")
  if [[ "${contributor}" -eq 1 ]]
  then
    flags+=("--contributor")
  fi

  invoke_entry "${root}" "${shell_bin}" "${entry}" "" "${flags[@]}" >/dev/null || return 1
  local skill_rel=""
  skill_rel="$(target_relpath "${target}")" || return 1
  verify_skills "${home}/${skill_rel}" "${contributor}" || return 1

  jq -e \
    --arg hooks_dir "${payload_dir}/hooks" \
    '
      .existing_setting == "preserve-me"
      and .hooks.PreToolUse[0].hooks[0].command == "echo preserved"
      and (
        ["PreToolUse", "SessionStart", "UserPromptSubmit"]
        | all(
            . as $ev
            | ([.. | objects | select(has("hooks")) | .hooks[]? | select(false)] | length == 0)
            and (
              [ $root.hooks[$ev][]?.hooks[]? | select(.command | contains($hooks_dir)) ]
              | length == 1
            )
          )
      )
    ' --argjson root "$(cat "${config_file}")" "${config_file}" >/dev/null ||
    {
      case_fail "hook configuration missing, duplicated, or overwrote existing settings"
      return 1
    }

  [[ ! -e "${home}/${opposite_rel}" ]] || {
    case_fail "hook registered for unselected agent"
    return 1
  }

  snapshot_tree "${home}" "${root}/before.tree"
  invoke_entry "${root}" "${shell_bin}" "${entry}" "" "${flags[@]}" >/dev/null || return 1
  snapshot_tree "${home}" "${root}/after.tree"
  cmp -s "${root}/before.tree" "${root}/after.tree" || {
    case_fail "repeat hook install changed or duplicated configuration"
    return 1
  }
}

run_cli_contract_case() {
  local label="$1"
  local entry="$2"
  local shell_bin="$3"

  local root=""
  root="$(setup_case_env "${shell_bin}" "${label}")" || return 1
  local home="${root}/home"

  snapshot_tree "${home}" "${root}/before.tree"
  local help_text=""
  help_text="$(invoke_entry "${root}" "${shell_bin}" "${entry}" "" --help)" || return 1
  local t=""
  for t in "${TARGET_NAMES[@]}"
  do
    [[ "${help_text}" = *"--${t}"* ]] || {
      case_fail "target missing from help: --${t}"
      return 1
    }
  done

  local listing=""
  listing="$(invoke_entry "${root}" "${shell_bin}" "${entry}" "" --list)" || return 1
  for t in claude codex agy kimi grok copilot
  do
    printf '%s\n' "${listing}" | grep -Eq "^[[:space:]]*${t}[[:space:]]+not found[[:space:]]+" ||
      {
        case_fail "non-isolated agent detection for ${t}"
        return 1
      }
  done

  local bad_rc=0
  (
    cd "${home}" &&
      "${ENV_BIN}" -i \
        "HOME=${home}" \
        "PATH=${root}/bin" \
        "LC_ALL=C" \
        "TMPDIR=${root}/tmp" \
        "RIPWIRE_PKGSHARE=${payload_dir}" \
        "${shell_bin}" "${entry}" --invalid-integration-flag
  ) >"${root}/bad.out" 2>"${root}/bad.err" || bad_rc=$?

  [[ "${bad_rc}" -eq 2 ]] || {
    case_fail "unknown option did not exit 2 (got ${bad_rc})"
    return 1
  }
  grep -Fq "Unknown option" "${root}/bad.err" || {
    case_fail "missing unknown option diagnostic"
    return 1
  }

  snapshot_tree "${home}" "${root}/after.tree"
  cmp -s "${root}/before.tree" "${root}/after.tree" || {
    case_fail "non-installing CLI action changed agent state"
    return 1
  }
}

results_jsonl="${scratch}/results.jsonl"
: >"${results_jsonl}"
passed_count=0
failed_count=0

record_case() {
  local case_name="$1"
  shift
  local err_capture="${scratch}/.case-err.$$"
  if "$@" 2>"${err_capture}"
  then
    passed_count=$((passed_count + 1))
    jq -cn --arg c "${case_name}" '{case: $c, passed: true}' >>"${results_jsonl}"
    printf 'PASS %s\n' "${case_name}"
  else
    failed_count=$((failed_count + 1))
    local err_text=""
    err_text="$(cat "${err_capture}")"
    jq -cn --arg c "${case_name}" --arg e "${err_text}" '{case: $c, passed: false, error: $e}' >>"${results_jsonl}"
    printf 'FAIL %s: %s\n' "${case_name}" "${err_text}"
  fi
  rm -f -- "${err_capture}"
}

ENTRY_NAMES=(formula standalone)
ENTRY_PATHS=("${wrapper_snapshot}" "${standalone_snapshot}")
SHELL_NAMES=(bash32 modern)
SHELL_PATHS=("${bash32}" "${modern_bash}")

for e_idx in 0 1
do
  entry_name="${ENTRY_NAMES[${e_idx}]}"
  entry_path="${ENTRY_PATHS[${e_idx}]}"
  for s_idx in 0 1
  do
    shell_name="${SHELL_NAMES[${s_idx}]}"
    shell_path="${SHELL_PATHS[${s_idx}]}"

    for kind in default custom_agy shared_hook
    do
      c_name="${entry_name}-${shell_name}-${kind}"
      record_case "${c_name}" run_regression_case "${c_name}" "${entry_path}" "${shell_path}" "${kind}"
    done

    if [[ "${regressions_only}" -eq 1 ]]
    then
      continue
    fi

    for target in default all "${TARGET_NAMES[@]}"
    do
      for contributor in 0 1
      do
        c_name="${entry_name}-${shell_name}-${target}-contributor${contributor}"
        record_case "${c_name}" run_install_matrix_case \
          "${c_name}" "${entry_path}" "${shell_path}" "${target}" "${contributor}"
      done
    done

    for target in claude codex
    do
      for contributor in 0 1
      do
        c_name="${entry_name}-${shell_name}-${target}-hook-contributor${contributor}"
        record_case "${c_name}" run_hook_install_case \
          "${c_name}" "${entry_path}" "${shell_path}" "${target}" "${contributor}"
      done
    done

    c_name="${entry_name}-${shell_name}-cli-contract"
    record_case "${c_name}" run_cli_contract_case "${c_name}" "${entry_path}" "${shell_path}"
  done
done

mkdir -p "$(dirname "${receipt_path}")"
jq -s \
  --arg scratch "${scratch}" \
  --arg installer_sha "${INSTALLER_SHA256}" \
  --arg formula_sha "${formula_sha}" \
  --arg standalone_sha "${standalone_sha}" \
  --argjson passed "${passed_count}" \
  --argjson failed "${failed_count}" \
  '{
    scratch: $scratch,
    installer_sha256: $installer_sha,
    source_sha256: {
      "Formula/ripwire.rb": $formula_sha,
      "scripts/install-agent-skills.sh": $standalone_sha
    },
    results: .,
    passed: $passed,
    failed: $failed
  }' "${results_jsonl}" >"${receipt_path}"

printf 'Receipt: %s\n' "${receipt_path}"
[[ "${failed_count}" -eq 0 ]]
