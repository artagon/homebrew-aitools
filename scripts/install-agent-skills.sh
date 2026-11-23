#!/usr/bin/env bash
# install-agent-skills.sh — Multi-tool, multi-agent skill and hook installer
# Tools: ripwire, agent-mail, acli, all
# Supports: Claude Code, OpenAI Codex, Google Antigravity (Agy), Moonshot Kimi,
#           Grok, GitHub Copilot, OpenCode, Gemini CLI, Qwen Code

# The detect_* and find_tool_pkgshare helpers report through their exit status,
# so calling them in && / || tests and $(...) is intended (brew style enables
# these optional checks).
# shellcheck disable=SC2310,SC2312

set -euo pipefail

# ── Locate a Tool's Bundled pkgshare ─────────────────────────────────────────
canonicalize_dir() {
  (cd "$1" && pwd -P)
}

find_tool_pkgshare() {
  local tool="$1"
  local env_override=""

  case "${tool}" in
    ripwire) env_override="${RIPWIRE_PKGSHARE:-}" ;;
    agent-mail) env_override="${AGENT_MAIL_PKGSHARE:-}" ;;
    acli) env_override="${ACLI_PKGSHARE:-}" ;;
    *) return 1 ;;
  esac

  if [[ -n "${env_override}" ]]
  then
    if [[ -d "${env_override}" ]]
    then
      canonicalize_dir "${env_override}"
      return 0
    fi
    return 1
  fi

  if command -v brew >/dev/null 2>&1
  then
    local brew_prefix
    brew_prefix="$(brew --prefix "${tool}" 2>/dev/null || true)"
    if [[ -n "${brew_prefix}" ]] && [[ -d "${brew_prefix}/share/${tool}" ]]
    then
      canonicalize_dir "${brew_prefix}/share/${tool}"
      return 0
    fi
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  if [[ -d "${script_dir}/../share/${tool}" ]]
  then
    canonicalize_dir "${script_dir}/../share/${tool}"
    return 0
  fi

  local candidate
  for candidate in "/opt/homebrew/share/${tool}" "/usr/local/share/${tool}" "/home/linuxbrew/.linuxbrew/share/${tool}"
  do
    if [[ -d "${candidate}" ]]
    then
      canonicalize_dir "${candidate}"
      return 0
    fi
  done

  return 1
}

resolve_ripwire_installer() {
  if [[ -n "${RIPWIRE_INSTALLER:-}" ]]
  then
    if [[ ! -f "${RIPWIRE_INSTALLER}" ]]
    then
      echo "Error: Ripwire installer not found at ${RIPWIRE_INSTALLER}" >&2
      return 1
    fi
    echo "${RIPWIRE_INSTALLER}"
    return 0
  fi

  local pkgshare
  pkgshare="$(find_tool_pkgshare ripwire || true)"
  if [[ -z "${pkgshare}" ]] || [[ ! -f "${pkgshare}/skills/install.sh" ]]
  then
    echo "Error: Could not locate Ripwire's bundled skills/install.sh." >&2
    echo "Ensure 'ripwire' is installed (brew install artagon/aitools/ripwire) or set RIPWIRE_PKGSHARE." >&2
    return 1
  fi
  echo "${pkgshare}/skills/install.sh"
}

# ── Agent Detection ──────────────────────────────────────────────────────────
detect_claude() {
  command -v claude >/dev/null 2>&1 || [[ -d "${HOME}/.claude" ]]
}

detect_codex() {
  command -v codex >/dev/null 2>&1 || [[ -d "${CODEX_HOME:-${HOME}/.codex}" ]]
}

detect_agy() {
  command -v agy >/dev/null 2>&1 || [[ -d "${AGY_SKILLS_DIR:-${HOME}/.gemini/antigravity-cli/skills}" ]] || [[ -d "${HOME}/.gemini" ]]
}

detect_kimi() {
  command -v kimi >/dev/null 2>&1 || [[ -d "${KIMI_CODE_HOME:-${HOME}/.kimi-code}" ]]
}

detect_grok() {
  command -v grok >/dev/null 2>&1 || [[ -d "${GROK_HOME:-${HOME}/.grok}" ]]
}

detect_copilot() {
  command -v copilot >/dev/null 2>&1 || [[ -d "${COPILOT_HOME:-${HOME}/.copilot}" ]]
}

detect_opencode() {
  command -v opencode >/dev/null 2>&1 ||
    [[ -d "${XDG_CONFIG_HOME:-${HOME}/.config}/opencode" ]] ||
    { [[ -n "${OPENCODE_SKILLS_DIR:-}" ]] && [[ -d "${OPENCODE_SKILLS_DIR}" ]]; }
}

detect_gemini() {
  local gemini_home="${GEMINI_HOME:-${HOME}/.gemini}"
  command -v gemini >/dev/null 2>&1 ||
    [[ -d "${gemini_home}/extensions" ]] ||
    [[ -f "${gemini_home}/settings.json" ]] ||
    [[ -d "${gemini_home}/skills" ]] ||
    { [[ -n "${GEMINI_SKILLS_DIR:-}" ]] && [[ -d "${GEMINI_SKILLS_DIR}" ]]; }
}

detect_qwen() {
  command -v qwen >/dev/null 2>&1 || [[ -d "${QWEN_HOME:-${HOME}/.qwen}" ]]
}

# ── Skill Bundle Installer for Non-Ripwire Tools ─────────────────────────────
readonly SAFE_SKILL_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'

install_pkgshare_skills() {
  local tool="$1"
  local pkgshare="$2"
  local dest="$3"
  local skills_root="${pkgshare}/skills"

  if [[ ! -d "${skills_root}" ]]
  then
    echo "Error: No bundled skills directory found for ${tool} at ${skills_root}" >&2
    return 1
  fi

  local -a skill_dirs=()
  local skill_md="" skill_dir="" skill_name=""
  shopt -s nullglob
  for skill_md in "${skills_root}"/*/SKILL.md
  do
    [[ -f "${skill_md}" ]] || continue
    skill_dir="$(dirname "${skill_md}")"
    skill_name="$(basename "${skill_dir}")"
    if [[ ! "${skill_name}" =~ ${SAFE_SKILL_NAME_RE} ]]
    then
      shopt -u nullglob
      echo "Error: Unsafe skill directory name in bundle: ${skill_name}" >&2
      return 1
    fi
    skill_dirs+=("${skill_dir}")
  done
  shopt -u nullglob

  if [[ "${#skill_dirs[@]}" -eq 0 ]]
  then
    echo "Error: No SKILL.md bundles found for ${tool} under ${skills_root}" >&2
    return 1
  fi

  local manifest="${dest}/.${tool}-manifest-v1"
  if [[ -L "${manifest}" ]]
  then
    echo "Error: Refusing to follow symlinked manifest ${manifest}" >&2
    return 1
  fi

  # Pre-check all target paths before mutating any destination entry.
  local target_link=""
  for skill_dir in "${skill_dirs[@]}"
  do
    skill_name="$(basename "${skill_dir}")"
    target_link="${dest}/${skill_name}"
    if [[ -e "${target_link}" ]] && [[ ! -L "${target_link}" ]]
    then
      echo "Error: Refusing to overwrite non-symlink skill path ${target_link}" >&2
      return 1
    fi
  done

  mkdir -p "${dest}"

  local tmp_manifest=""
  tmp_manifest="$(mktemp "${dest}/.${tool}-manifest-v1.XXXXXX")"
  printf 'version=1\n' >"${tmp_manifest}"

  for skill_dir in "${skill_dirs[@]}"
  do
    skill_name="$(basename "${skill_dir}")"
    target_link="${dest}/${skill_name}"
    ln -sfn "${skill_dir}" "${target_link}"
    printf 'skill=%s\n' "${skill_name}" >>"${tmp_manifest}"
  done

  if [[ -f "${manifest}" ]] && [[ ! -L "${manifest}" ]]
  then
    local line="" old_skill="" still_present=0 cur_dir=""
    while IFS= read -r line || [[ -n "${line}" ]]
    do
      [[ "${line}" == skill=* ]] || continue
      old_skill="${line#skill=}"
      if [[ ! "${old_skill}" =~ ${SAFE_SKILL_NAME_RE} ]]
      then
        continue
      fi
      still_present=0
      for cur_dir in "${skill_dirs[@]}"
      do
        if [[ "$(basename "${cur_dir}")" = "${old_skill}" ]]
        then
          still_present=1
          break
        fi
      done
      if [[ "${still_present}" -eq 0 ]] && [[ -L "${dest}/${old_skill}" ]]
      then
        rm -f -- "${dest}/${old_skill}"
      fi
    done <"${manifest}"
  fi

  mv "${tmp_manifest}" "${manifest}"
}

# ── Help / Usage ─────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install bundled artagon/aitools agent skills (and Ripwire hooks) across AI agent CLIs.

Tool Selection:
  --tool TOOL    Tool bundle to install: ripwire (default), agent-mail, acli, or all
                 (may be repeated; agent-mail and acli do not require ripwire)

Supported Agent CLIs:
  --claude       Claude Code                  (~/.claude/skills)
  --codex        OpenAI Codex                 (~/.agents/skills)
  --agy          Google Antigravity (Agy)     (~/.gemini/antigravity-cli/skills)
  --kimi         Moonshot Kimi Code           (~/.kimi-code/skills)
  --grok         Grok CLI                     (~/.grok/skills)
  --copilot      GitHub Copilot CLI           (~/.copilot/skills)
  --opencode     OpenCode                     (~/.config/opencode/skills)
  --gemini       Gemini CLI                   (~/.gemini/skills)
  --qwen         Qwen Code                    (~/.qwen/skills)
  --shared       Cross-Agent shared root      (~/.agents/skills)

General Options:
  --all          Install for all detected agent CLIs (default if no agent specified)
  --hook         Register Ripwire advisory hooks (Claude and Codex; requires jq)
  --contributor  Include Ripwire contributor-only skills (e.g. ripwire-opt-remarks)
  --list         List detected agent CLIs and their status without installing
  -h, --help     Show this help message

Examples:
  $(basename "$0")                          # Auto-detect installed CLIs and install Ripwire skills
  $(basename "$0") --tool agent-mail --all  # Install Agent Mail skills without requiring Ripwire
  $(basename "$0") --tool acli --claude     # Install acli skills for Claude Code
  $(basename "$0") --tool all --all         # Install skills for all installed tools and CLIs
  $(basename "$0") --claude --hook          # Install Ripwire skills + hooks for Claude Code
EOF
}

# ── Parse Arguments ──────────────────────────────────────────────────────────
want_tool_ripwire=0
want_tool_agent_mail=0
want_tool_acli=0
want_tool_all=0
explicit_tool=0

want_claude=0
want_codex=0
want_agy=0
want_kimi=0
want_grok=0
want_copilot=0
want_opencode=0
want_gemini=0
want_qwen=0
want_shared=0
want_all=0
want_hook=0
want_contributor=0
action_list=0
explicit_selection=0

select_tool() {
  local tool="$1"
  explicit_tool=1
  case "${tool}" in
    ripwire) want_tool_ripwire=1 ;;
    agent-mail) want_tool_agent_mail=1 ;;
    acli) want_tool_acli=1 ;;
    all) want_tool_all=1 ;;
    *)
      echo "Unknown tool: ${tool} (expected ripwire, agent-mail, acli, or all)" >&2
      usage >&2
      exit 2
      ;;
  esac
}

while [[ $# -gt 0 ]]
do
  case "$1" in
    --tool)
      if [[ $# -lt 2 ]]
      then
        echo "Missing argument for --tool" >&2
        usage >&2
        exit 2
      fi
      select_tool "$2"
      shift
      ;;
    --tool=*)
      select_tool "${1#--tool=}"
      ;;
    --claude)
      want_claude=1
      explicit_selection=1
      ;;
    --codex)
      want_codex=1
      explicit_selection=1
      ;;
    --agy)
      want_agy=1
      explicit_selection=1
      ;;
    --kimi)
      want_kimi=1
      explicit_selection=1
      ;;
    --grok)
      want_grok=1
      explicit_selection=1
      ;;
    --copilot)
      want_copilot=1
      explicit_selection=1
      ;;
    --opencode)
      want_opencode=1
      explicit_selection=1
      ;;
    --gemini)
      want_gemini=1
      explicit_selection=1
      ;;
    --qwen)
      want_qwen=1
      explicit_selection=1
      ;;
    --shared)
      want_shared=1
      explicit_selection=1
      ;;
    --all) want_all=1 ;;
    --hook) want_hook=1 ;;
    --contributor) want_contributor=1 ;;
    --list) action_list=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      if [[ $# -gt 0 ]]
      then
        echo "Unexpected positional argument: $1" >&2
        usage >&2
        exit 2
      fi
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "${explicit_tool}" -eq 0 ]]
then
  want_tool_ripwire=1
fi

# ── Action: List Detected Agents ─────────────────────────────────────────────
if [[ "${action_list}" -eq 1 ]]
then
  echo "Detected Agent CLIs:"
  printf "  %-12s %-12s %s\n" "CLI" "Status" "Skills Target Path"
  printf "  %-12s %-12s %s\n" "---" "------" "------------------"
  printf "  %-12s %-12s %s\n" "claude" "$(detect_claude && echo 'installed' || echo 'not found')" "${HOME}/.claude/skills"
  printf "  %-12s %-12s %s\n" "codex" "$(detect_codex && echo 'installed' || echo 'not found')" "${AGENTS_HOME:-${HOME}/.agents}/skills"
  printf "  %-12s %-12s %s\n" "agy" "$(detect_agy && echo 'installed' || echo 'not found')" "${AGY_SKILLS_DIR:-${HOME}/.gemini/antigravity-cli/skills}"
  printf "  %-12s %-12s %s\n" "kimi" "$(detect_kimi && echo 'installed' || echo 'not found')" "${KIMI_CODE_HOME:-${HOME}/.kimi-code}/skills"
  printf "  %-12s %-12s %s\n" "grok" "$(detect_grok && echo 'installed' || echo 'not found')" "${GROK_HOME:-${HOME}/.grok}/skills"
  printf "  %-12s %-12s %s\n" "copilot" "$(detect_copilot && echo 'installed' || echo 'not found')" "${COPILOT_HOME:-${HOME}/.copilot}/skills"
  printf "  %-12s %-12s %s\n" "opencode" "$(detect_opencode && echo 'installed' || echo 'not found')" "${OPENCODE_SKILLS_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills}"
  printf "  %-12s %-12s %s\n" "gemini" "$(detect_gemini && echo 'installed' || echo 'not found')" "${GEMINI_SKILLS_DIR:-${GEMINI_HOME:-${HOME}/.gemini}/skills}"
  printf "  %-12s %-12s %s\n" "qwen" "$(detect_qwen && echo 'installed' || echo 'not found')" "${QWEN_HOME:-${HOME}/.qwen}/skills"
  exit 0
fi

# ── Auto-Detection when no specific CLI chosen ───────────────────────────────
if [[ "${explicit_selection}" -eq 0 ]] || [[ "${want_all}" -eq 1 ]]
then
  detect_claude && want_claude=1
  detect_codex && want_codex=1
  detect_agy && want_agy=1
  detect_kimi && want_kimi=1
  detect_grok && want_grok=1
  detect_copilot && want_copilot=1
  detect_opencode && want_opencode=1
  detect_gemini && want_gemini=1
  detect_qwen && want_qwen=1

  # If nothing detected at all, default to cross-agent shared root
  if [[ "${want_claude}" -eq 0 ]] && [[ "${want_codex}" -eq 0 ]] && [[ "${want_agy}" -eq 0 ]] &&
     [[ "${want_kimi}" -eq 0 ]] && [[ "${want_grok}" -eq 0 ]] && [[ "${want_copilot}" -eq 0 ]] &&
     [[ "${want_opencode}" -eq 0 ]] && [[ "${want_gemini}" -eq 0 ]] && [[ "${want_qwen}" -eq 0 ]]
  then
    echo "No specific agent CLI detected on host. Defaulting to shared ~/.agents/skills..."
    want_shared=1
  fi
fi

# ── Resolve Tool Bundles ─────────────────────────────────────────────────────
INSTALLER=""
AGENT_MAIL_SHARE=""
ACLI_SHARE=""
resolved_tools=0

if [[ "${want_tool_all}" -eq 1 ]]
then
  if INSTALLER="$(resolve_ripwire_installer 2>/dev/null)"
  then
    want_tool_ripwire=1
    resolved_tools=$((resolved_tools + 1))
  fi
  if AGENT_MAIL_SHARE="$(find_tool_pkgshare agent-mail || true)" && [[ -n "${AGENT_MAIL_SHARE}" ]] && [[ -d "${AGENT_MAIL_SHARE}/skills" ]]
  then
    want_tool_agent_mail=1
    resolved_tools=$((resolved_tools + 1))
  fi
  if ACLI_SHARE="$(find_tool_pkgshare acli || true)" && [[ -n "${ACLI_SHARE}" ]] && [[ -d "${ACLI_SHARE}/skills" ]]
  then
    want_tool_acli=1
    resolved_tools=$((resolved_tools + 1))
  fi
  if [[ "${resolved_tools}" -eq 0 ]]
  then
    echo "Error: No supported tool skill bundles (ripwire, agent-mail, acli) found on host." >&2
    exit 1
  fi
else
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    INSTALLER="$(resolve_ripwire_installer)"
    resolved_tools=$((resolved_tools + 1))
  fi
  if [[ "${want_tool_agent_mail}" -eq 1 ]]
  then
    AGENT_MAIL_SHARE="$(find_tool_pkgshare agent-mail || true)"
    if [[ -z "${AGENT_MAIL_SHARE}" ]] || [[ ! -d "${AGENT_MAIL_SHARE}/skills" ]]
    then
      echo "Error: Could not locate Agent Mail's bundled skills directory." >&2
      echo "Ensure 'agent-mail' is installed (brew install artagon/aitools/agent-mail) or set AGENT_MAIL_PKGSHARE." >&2
      exit 1
    fi
    resolved_tools=$((resolved_tools + 1))
  fi
  if [[ "${want_tool_acli}" -eq 1 ]]
  then
    ACLI_SHARE="$(find_tool_pkgshare acli || true)"
    if [[ -z "${ACLI_SHARE}" ]] || [[ ! -d "${ACLI_SHARE}/skills" ]]
    then
      echo "Error: Could not locate acli's bundled skills directory." >&2
      echo "Ensure 'acli' is installed (brew install artagon/aitools/acli) or set ACLI_PKGSHARE." >&2
      exit 1
    fi
    resolved_tools=$((resolved_tools + 1))
  fi
fi

# ── Helper to Install Non-Ripwire Bundles to a Target Path ───────────────────
install_extra_tools_for_target() {
  local label="$1"
  local dest="$2"
  if [[ "${want_tool_agent_mail}" -eq 1 ]]
  then
    echo "==> Installing Agent Mail skills for ${label} (${dest})..."
    install_pkgshare_skills agent-mail "${AGENT_MAIL_SHARE}" "${dest}"
  fi
  if [[ "${want_tool_acli}" -eq 1 ]]
  then
    echo "==> Installing acli skills for ${label} (${dest})..."
    install_pkgshare_skills acli "${ACLI_SHARE}" "${dest}"
  fi
}

# ── Execution ────────────────────────────────────────────────────────────────
# Keep every argument array nonempty for Bash 3.2 with nounset.
declare -a installer_args=()
if [[ "${want_tool_ripwire}" -eq 1 ]]
then
  installer_args=("${INSTALLER}")
  [[ "${want_contributor}" -eq 1 ]] && installer_args+=("--contributor")
fi

installed_count=0

# Claude Code
if [[ "${want_claude}" -eq 1 ]]
then
  claude_dst="${HOME}/.claude/skills"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for Claude Code (~/.claude/skills)..."
    claude_args=("${installer_args[@]}" --claude)
    [[ "${want_hook}" -eq 1 ]] && claude_args+=("--hook")
    bash "${claude_args[@]}"
  fi
  install_extra_tools_for_target "Claude Code" "${claude_dst}"
  installed_count=$((installed_count + 1))
fi

# OpenAI Codex
if [[ "${want_codex}" -eq 1 ]]
then
  codex_dst="${AGENTS_HOME:-${HOME}/.agents}/skills"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for OpenAI Codex (${codex_dst})..."
    codex_args=("${installer_args[@]}" --codex)
    [[ "${want_hook}" -eq 1 ]] && codex_args+=("--hook")
    bash "${codex_args[@]}"
  fi
  install_extra_tools_for_target "OpenAI Codex" "${codex_dst}"
  installed_count=$((installed_count + 1))
fi

# Google Antigravity (Agy)
if [[ "${want_agy}" -eq 1 ]]
then
  agy_dst="${AGY_SKILLS_DIR:-${HOME}/.gemini/antigravity-cli/skills}"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for Google Antigravity (${agy_dst})..."
    mkdir -p "${agy_dst}"
    bash "${installer_args[@]}" "${agy_dst}"
  fi
  install_extra_tools_for_target "Google Antigravity" "${agy_dst}"
  installed_count=$((installed_count + 1))
fi

# Moonshot Kimi Code
if [[ "${want_kimi}" -eq 1 ]]
then
  kimi_dst="${KIMI_CODE_HOME:-${HOME}/.kimi-code}/skills"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for Kimi Code (${kimi_dst})..."
    mkdir -p "${kimi_dst}"
    bash "${installer_args[@]}" "${kimi_dst}"
  fi
  install_extra_tools_for_target "Kimi Code" "${kimi_dst}"
  installed_count=$((installed_count + 1))
fi

# Grok CLI
if [[ "${want_grok}" -eq 1 ]]
then
  grok_dst="${GROK_HOME:-${HOME}/.grok}/skills"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for Grok (${grok_dst})..."
    mkdir -p "${grok_dst}"
    bash "${installer_args[@]}" "${grok_dst}"
  fi
  install_extra_tools_for_target "Grok" "${grok_dst}"
  installed_count=$((installed_count + 1))
fi

# GitHub Copilot CLI
if [[ "${want_copilot}" -eq 1 ]]
then
  copilot_dst="${COPILOT_HOME:-${HOME}/.copilot}/skills"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for GitHub Copilot (${copilot_dst})..."
    mkdir -p "${copilot_dst}"
    bash "${installer_args[@]}" "${copilot_dst}"
  fi
  install_extra_tools_for_target "GitHub Copilot" "${copilot_dst}"
  installed_count=$((installed_count + 1))
fi

# OpenCode
if [[ "${want_opencode}" -eq 1 ]]
then
  opencode_dst="${OPENCODE_SKILLS_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills}"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for OpenCode (${opencode_dst})..."
    mkdir -p "${opencode_dst}"
    bash "${installer_args[@]}" "${opencode_dst}"
  fi
  install_extra_tools_for_target "OpenCode" "${opencode_dst}"
  installed_count=$((installed_count + 1))
fi

# Gemini CLI
if [[ "${want_gemini}" -eq 1 ]]
then
  gemini_dst="${GEMINI_SKILLS_DIR:-${GEMINI_HOME:-${HOME}/.gemini}/skills}"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for Gemini CLI (${gemini_dst})..."
    mkdir -p "${gemini_dst}"
    bash "${installer_args[@]}" "${gemini_dst}"
  fi
  install_extra_tools_for_target "Gemini CLI" "${gemini_dst}"
  installed_count=$((installed_count + 1))
fi

# Qwen Code
if [[ "${want_qwen}" -eq 1 ]]
then
  qwen_dst="${QWEN_HOME:-${HOME}/.qwen}/skills"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for Qwen Code (${qwen_dst})..."
    mkdir -p "${qwen_dst}"
    bash "${installer_args[@]}" "${qwen_dst}"
  fi
  install_extra_tools_for_target "Qwen Code" "${qwen_dst}"
  installed_count=$((installed_count + 1))
fi

# Cross-agent shared root
if [[ "${want_shared}" -eq 1 ]]
then
  shared_dst="${AGENTS_HOME:-${HOME}/.agents}/skills"
  if [[ "${want_tool_ripwire}" -eq 1 ]]
  then
    echo "==> Installing Ripwire skills for Cross-Agent shared root (${shared_dst})..."
    mkdir -p "${shared_dst}"
    bash "${installer_args[@]}" "${shared_dst}"
  fi
  install_extra_tools_for_target "Cross-Agent shared root" "${shared_dst}"
  installed_count=$((installed_count + 1))
fi

has_non_hook_target() {
  [[ "${want_agy}" -eq 1 ]] || [[ "${want_kimi}" -eq 1 ]] || [[ "${want_grok}" -eq 1 ]] ||
    [[ "${want_copilot}" -eq 1 ]] || [[ "${want_opencode}" -eq 1 ]] || [[ "${want_gemini}" -eq 1 ]] ||
    [[ "${want_qwen}" -eq 1 ]]
}

if [[ "${want_tool_ripwire}" -eq 1 ]] && [[ "${want_hook}" -eq 1 ]] && has_non_hook_target
then
  echo ""
  echo "Note: Ripwire advisory hooks are natively supported for Claude Code and Codex."
  echo "For Antigravity, Kimi, Grok, Copilot, OpenCode, Gemini, and Qwen, Ripwire operates via skills and its MCP server ('ripwire --mcp')."
fi

echo ""
echo "Installation complete for ${installed_count} agent target(s)."
