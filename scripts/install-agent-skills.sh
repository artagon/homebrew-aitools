#!/usr/bin/env bash
# install-agent-skills.sh — Multi-agent skill and hook installer for Ripwire
# Supports: Claude Code, OpenAI Codex, Google Antigravity (Agy), Moonshot Kimi, Grok, GitHub Copilot

set -euo pipefail

# ── Locate Ripwire's bundled pkgshare ─────────────────────────────────────────
find_pkgshare() {
  if [ -n "${RIPWIRE_PKGSHARE:-}" ] && [ -d "$RIPWIRE_PKGSHARE" ]; then
    echo "$RIPWIRE_PKGSHARE"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    local brew_prefix
    brew_prefix="$(brew --prefix ripwire 2>/dev/null || true)"
    if [ -n "$brew_prefix" ] && [ -d "$brew_prefix/share/ripwire" ]; then
      echo "$brew_prefix/share/ripwire"
      return 0
    fi
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -d "$script_dir/../share/ripwire" ]; then
    echo "$script_dir/../share/ripwire"
    return 0
  fi

  for candidate in /opt/homebrew/share/ripwire /usr/local/share/ripwire; do
    if [ -d "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

PKGSHARE="$(find_pkgshare || true)"
if [ -z "$PKGSHARE" ] || [ ! -f "$PKGSHARE/skills/install.sh" ]; then
  echo "Error: Could not locate Ripwire's bundled skills/install.sh." >&2
  echo "Ensure 'ripwire' is installed (brew install artagon/aitools/ripwire) or set RIPWIRE_PKGSHARE." >&2
  exit 1
fi

INSTALLER="$PKGSHARE/skills/install.sh"

# ── Agent Detection ──────────────────────────────────────────────────────────
detect_claude() {
  command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]
}

detect_codex() {
  command -v codex >/dev/null 2>&1 || [ -d "${CODEX_HOME:-$HOME/.codex}" ]
}

detect_agy() {
  command -v agy >/dev/null 2>&1 || [ -d "${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}" ] || [ -d "$HOME/.gemini" ]
}

detect_kimi() {
  command -v kimi >/dev/null 2>&1 || [ -d "${KIMI_CODE_HOME:-$HOME/.kimi-code}" ]
}

detect_grok() {
  command -v grok >/dev/null 2>&1 || [ -d "${GROK_HOME:-$HOME/.grok}" ]
}

detect_copilot() {
  command -v copilot >/dev/null 2>&1 || [ -d "${COPILOT_HOME:-$HOME/.copilot}" ]
}

# ── Help / Usage ─────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Ripwire agent skills and hooks across AI agent CLIs.

Supported Agent CLIs:
  --claude       Claude Code                  (~/.claude/skills)
  --codex        OpenAI Codex                 (~/.agents/skills)
  --agy          Google Antigravity (Agy)     (~/.gemini/antigravity-cli/skills)
  --kimi         Moonshot Kimi Code           (~/.kimi-code/skills)
  --grok         Grok CLI                     (~/.grok/skills)
  --copilot      GitHub Copilot CLI           (~/.copilot/skills)
  --shared       Cross-Agent shared root      (~/.agents/skills)

General Options:
  --all          Install for all detected agent CLIs (default if no agent specified)
  --hook         Register advisory hooks (supported for Claude and Codex; requires jq)
  --contributor  Include contributor-only skills (e.g. ripwire-opt-remarks)
  --list         List detected agent CLIs and their status without installing
  -h, --help     Show this help message

Examples:
  $(basename "$0")                  # Auto-detect installed CLIs and install skills
  $(basename "$0") --all --hook     # Auto-detect and install skills + hooks
  $(basename "$0") --claude --hook  # Install specifically for Claude Code with hooks
  $(basename "$0") --agy --kimi     # Install specifically for Antigravity and Kimi
EOF
}

# ── Parse Arguments ──────────────────────────────────────────────────────────
want_claude=0
want_codex=0
want_agy=0
want_kimi=0
want_grok=0
want_copilot=0
want_shared=0
want_all=0
want_hook=0
want_contributor=0
action_list=0
explicit_selection=0

while [ $# -gt 0 ]; do
  case "$1" in
    --claude)      want_claude=1; explicit_selection=1 ;;
    --codex)       want_codex=1; explicit_selection=1 ;;
    --agy)         want_agy=1; explicit_selection=1 ;;
    --kimi)        want_kimi=1; explicit_selection=1 ;;
    --grok)        want_grok=1; explicit_selection=1 ;;
    --copilot)     want_copilot=1; explicit_selection=1 ;;
    --shared)      want_shared=1; explicit_selection=1 ;;
    --all)         want_all=1 ;;
    --hook)        want_hook=1 ;;
    --contributor) want_contributor=1 ;;
    --list)        action_list=1 ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# ── Action: List Detected Agents ─────────────────────────────────────────────
if [ "$action_list" -eq 1 ]; then
  echo "Detected Agent CLIs:"
  printf "  %-12s %-12s %s\n" "CLI" "Status" "Skills Target Path"
  printf "  %-12s %-12s %s\n" "---" "------" "------------------"
  printf "  %-12s %-12s %s\n" "claude"  "$(detect_claude  && echo 'installed' || echo 'not found')" "$HOME/.claude/skills"
  printf "  %-12s %-12s %s\n" "codex"   "$(detect_codex   && echo 'installed' || echo 'not found')" "${AGENTS_HOME:-$HOME/.agents}/skills"
  printf "  %-12s %-12s %s\n" "agy"     "$(detect_agy     && echo 'installed' || echo 'not found')" "${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}"
  printf "  %-12s %-12s %s\n" "kimi"    "$(detect_kimi    && echo 'installed' || echo 'not found')" "${KIMI_CODE_HOME:-$HOME/.kimi-code}/skills"
  printf "  %-12s %-12s %s\n" "grok"    "$(detect_grok    && echo 'installed' || echo 'not found')" "${GROK_HOME:-$HOME/.grok}/skills"
  printf "  %-12s %-12s %s\n" "copilot" "$(detect_copilot && echo 'installed' || echo 'not found')" "${COPILOT_HOME:-$HOME/.copilot}/skills"
  exit 0
fi

# ── Auto-Detection when no specific CLI chosen ───────────────────────────────
if [ "$explicit_selection" -eq 0 ] || [ "$want_all" -eq 1 ]; then
  detect_claude  && want_claude=1
  detect_codex   && want_codex=1
  detect_agy     && want_agy=1
  detect_kimi    && want_kimi=1
  detect_grok    && want_grok=1
  detect_copilot && want_copilot=1

  # If nothing detected at all, default to cross-agent shared root
  if [ "$want_claude" -eq 0 ] && [ "$want_codex" -eq 0 ] && [ "$want_agy" -eq 0 ] && \
     [ "$want_kimi" -eq 0 ] && [ "$want_grok" -eq 0 ] && [ "$want_copilot" -eq 0 ]; then
    echo "No specific agent CLI detected on host. Defaulting to shared ~/.agents/skills..."
    want_shared=1
  fi
fi

# ── Execution ────────────────────────────────────────────────────────────────
# Keep every argument array nonempty for Bash 3.2 with nounset.
installer_args=("$INSTALLER")
[ "$want_contributor" -eq 1 ] && installer_args+=("--contributor")

installed_count=0

# Claude Code
if [ "$want_claude" -eq 1 ]; then
  echo "==> Installing Ripwire skills for Claude Code (~/.claude/skills)..."
  claude_args=("${installer_args[@]}" --claude)
  [ "$want_hook" -eq 1 ] && claude_args+=("--hook")
  bash "${claude_args[@]}"
  installed_count=$((installed_count + 1))
fi

# OpenAI Codex
if [ "$want_codex" -eq 1 ]; then
  echo "==> Installing Ripwire skills for OpenAI Codex (${AGENTS_HOME:-$HOME/.agents}/skills)..."
  codex_args=("${installer_args[@]}" --codex)
  [ "$want_hook" -eq 1 ] && codex_args+=("--hook")
  bash "${codex_args[@]}"
  installed_count=$((installed_count + 1))
fi

# Google Antigravity (Agy)
if [ "$want_agy" -eq 1 ]; then
  agy_dst="${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}"
  echo "==> Installing Ripwire skills for Google Antigravity ($agy_dst)..."
  mkdir -p "$agy_dst"
  bash "${installer_args[@]}" "$agy_dst"
  installed_count=$((installed_count + 1))
fi

# Moonshot Kimi Code
if [ "$want_kimi" -eq 1 ]; then
  kimi_dst="${KIMI_CODE_HOME:-$HOME/.kimi-code}/skills"
  echo "==> Installing Ripwire skills for Kimi Code ($kimi_dst)..."
  mkdir -p "$kimi_dst"
  bash "${installer_args[@]}" "$kimi_dst"
  installed_count=$((installed_count + 1))
fi

# Grok CLI
if [ "$want_grok" -eq 1 ]; then
  grok_dst="${GROK_HOME:-$HOME/.grok}/skills"
  echo "==> Installing Ripwire skills for Grok ($grok_dst)..."
  mkdir -p "$grok_dst"
  bash "${installer_args[@]}" "$grok_dst"
  installed_count=$((installed_count + 1))
fi

# GitHub Copilot CLI
if [ "$want_copilot" -eq 1 ]; then
  copilot_dst="${COPILOT_HOME:-$HOME/.copilot}/skills"
  echo "==> Installing Ripwire skills for GitHub Copilot ($copilot_dst)..."
  mkdir -p "$copilot_dst"
  bash "${installer_args[@]}" "$copilot_dst"
  installed_count=$((installed_count + 1))
fi

# Cross-agent shared root
if [ "$want_shared" -eq 1 ]; then
  shared_dst="${AGENTS_HOME:-$HOME/.agents}/skills"
  echo "==> Installing Ripwire skills for Cross-Agent shared root ($shared_dst)..."
  mkdir -p "$shared_dst"
  bash "${installer_args[@]}" "$shared_dst"
  installed_count=$((installed_count + 1))
fi

if [ "$want_hook" -eq 1 ] && { [ "$want_agy" -eq 1 ] || [ "$want_kimi" -eq 1 ] || [ "$want_grok" -eq 1 ] || [ "$want_copilot" -eq 1 ]; }; then
  echo ""
  echo "Note: Ripwire advisory hooks are natively supported for Claude Code and Codex."
  echo "For Antigravity, Kimi, Grok, and Copilot, Ripwire operates via skills and its MCP server ('ripwire --mcp')."
fi

echo ""
echo "Installation complete for $installed_count agent target(s)."
