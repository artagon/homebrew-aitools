#!/usr/bin/env bats
# Bats behavior and compatibility suite for multi-tool / 9-CLI skill installation
# in scripts/install-agent-skills.sh (`artagon-shell/shell-testing/v1`).

setup_file() {
  export MULTI_BASH32="${BATS_BASH32:-/bin/bash}"
  export MULTI_MODERN_BASH="${BATS_MODERN_BASH:-$(command -v bash)}"
  export MULTI_REPO_ROOT="${BATS_REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)}"
  export MULTI_SCRIPT="$MULTI_REPO_ROOT/scripts/install-agent-skills.sh"
  export MULTI_HAS_BASH32=0

  [[ -x "$MULTI_SCRIPT" ]] || {
    printf 'Missing executable skill installer: %s\n' "$MULTI_SCRIPT" >&2
    return 1
  }

  local mod_ver=""
  mod_ver="$("$MULTI_MODERN_BASH" --version | awk 'NR == 1 { print; exit }')"
  [[ "$mod_ver" =~ version\ [5-9]\. ]] || {
    printf 'BATS_MODERN_BASH must identify Bash 5+ (got: %s)\n' "$mod_ver" >&2
    return 1
  }

  local b32_ver=""
  if [[ -x "$MULTI_BASH32" ]]; then
    b32_ver="$("$MULTI_BASH32" --version | awk 'NR == 1 { print; exit }')"
  fi
  if [[ "$b32_ver" =~ version\ 3\.2\. ]]; then
    MULTI_HAS_BASH32=1
  elif [[ "$(uname -s)" = "Darwin" ]]; then
    printf 'BATS_BASH32 must identify Bash 3.2 on Darwin (got: %s)\n' "${b32_ver:-missing}" >&2
    return 1
  fi
}

setup() {
  if [[ "$BATS_TEST_DESCRIPTION" == "bash 3.2:"* ]] && [[ "${MULTI_HAS_BASH32:-0}" -ne 1 ]]; then
    skip "macOS Bash 3.2 interpreter is not installed on $(uname -s)"
  fi
  export HOME="$BATS_TEST_TMPDIR/home"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$HOME" "$TMPDIR"
}

setup_isolated_bin() {
  local bin_dir="$1"
  local shell_bin="$2"
  mkdir -p "$bin_dir"
  local cmd="" resolved=""
  for cmd in basename dirname mkdir grep rm ln mktemp mv chmod cat cp readlink; do
    resolved="$(command -v "$cmd")"
    ln -sf "$resolved" "$bin_dir/$cmd"
  done
  ln -sf "$shell_bin" "$bin_dir/bash"
}

case_multitool_no_ripwire_all_9_clis() {
  local shell_bin="$1"
  local root="$BATS_TEST_TMPDIR/case-multi"
  local home="$root/home"
  local bin_dir="$root/bin"
  local am_share="$root/share/agent-mail"
  local acli_share="$root/share/acli"
  mkdir -p "$home" "$am_share/skills/agent-mail" "$acli_share/skills/acli-messaging" "$acli_share/skills/acli-sandbox"
  setup_isolated_bin "$bin_dir" "$shell_bin"

  printf -- '---\nname: agent-mail\n---\n# Agent Mail\n' >"$am_share/skills/agent-mail/SKILL.md"
  printf -- '---\nname: acli-messaging\n---\n# acli messaging\n' >"$acli_share/skills/acli-messaging/SKILL.md"
  printf -- '---\nname: acli-sandbox\n---\n# acli sandbox\n' >"$acli_share/skills/acli-sandbox/SKILL.md"

  # 1. --list works without ripwire installed and lists all 9 CLIs.
  local listing=""
  listing="$(env -i HOME="$home" PATH="$bin_dir" LC_ALL=C TMPDIR="$TMPDIR" "$shell_bin" "$MULTI_SCRIPT" --list)"
  local cli=""
  for cli in claude codex agy kimi grok copilot opencode gemini qwen; do
    printf '%s\n' "$listing" | grep -Eq "^[[:space:]]*${cli}[[:space:]]+not found[[:space:]]+"
  done

  # 2. Install --tool agent-mail across all 9 CLIs explicitly with zero ripwire present.
  env -i HOME="$home" PATH="$bin_dir" LC_ALL=C TMPDIR="$TMPDIR" \
    AGENT_MAIL_PKGSHARE="$am_share" \
    "$shell_bin" "$MULTI_SCRIPT" --tool agent-mail \
    --claude --codex --agy --kimi --grok --copilot --opencode --gemini --qwen >/dev/null

  local rel=""
  for rel in \
    ".claude/skills" \
    ".agents/skills" \
    ".gemini/antigravity-cli/skills" \
    ".kimi-code/skills" \
    ".grok/skills" \
    ".copilot/skills" \
    ".config/opencode/skills" \
    ".gemini/skills" \
    ".qwen/skills"; do
    [[ -L "$home/$rel/agent-mail" ]]
    [[ -f "$home/$rel/agent-mail/SKILL.md" ]]
    [[ -f "$home/$rel/.agent-mail-manifest-v1" ]]
  done

  # 3. Install --tool acli with default auto-detection (detects all 9 CLI dirs) without ripwire.
  mkdir -p "$home/.claude" "$home/.codex" "$home/.kimi-code" "$home/.grok" "$home/.copilot" \
    "$home/.config/opencode" "$home/.gemini/extensions" "$home/.qwen"
  env -i HOME="$home" PATH="$bin_dir" LC_ALL=C TMPDIR="$TMPDIR" \
    ACLI_PKGSHARE="$acli_share" \
    "$shell_bin" "$MULTI_SCRIPT" --tool=acli --all >/dev/null

  for rel in \
    ".claude/skills" \
    ".agents/skills" \
    ".gemini/antigravity-cli/skills" \
    ".kimi-code/skills" \
    ".grok/skills" \
    ".copilot/skills" \
    ".config/opencode/skills" \
    ".gemini/skills" \
    ".qwen/skills"; do
    [[ -L "$home/$rel/acli-messaging" ]]
    [[ -L "$home/$rel/acli-sandbox" ]]
    [[ -f "$home/$rel/.acli-manifest-v1" ]]
  done

  # 4. --tool all installs available bundles (agent-mail + acli) when ripwire is explicitly absent (no host fallback), and prunes removed skills.
  rm -rf "$acli_share/skills/acli-sandbox"
  env -i HOME="$home" PATH="$bin_dir" LC_ALL=C TMPDIR="$TMPDIR" \
    RIPWIRE_PKGSHARE="$root/no-ripwire" \
    AGENT_MAIL_PKGSHARE="$am_share" \
    ACLI_PKGSHARE="$acli_share" \
    "$shell_bin" "$MULTI_SCRIPT" --tool all --claude >/dev/null
  [[ -L "$home/.claude/skills/agent-mail" ]]
  [[ -L "$home/.claude/skills/acli-messaging" ]]
  [[ ! -e "$home/.claude/skills/acli-sandbox" && ! -L "$home/.claude/skills/acli-sandbox" ]]
  [[ ! -e "$home/.claude/skills/.ripwire-manifest-v1" ]]

  # 5. Relative *_PKGSHARE resolves to canonical absolute symlinks.
  (
    cd "$root" || exit 1
    env -i HOME="$home" PATH="$bin_dir" LC_ALL=C TMPDIR="$TMPDIR" \
      AGENT_MAIL_PKGSHARE="./share/agent-mail" \
      "$shell_bin" "$MULTI_SCRIPT" --tool agent-mail --shared >/dev/null
  )
  local resolved_target=""
  resolved_target="$(readlink "$home/.agents/skills/agent-mail")"
  [[ "$resolved_target" = /* ]]
  [[ -f "$home/.agents/skills/agent-mail/SKILL.md" ]]

  # 6. Malicious manifest path traversal entry never deletes symlinks outside dest.
  local victim_src="$root/victim-src"
  local victim_link="$home/.claude/victim-link"
  mkdir -p "$victim_src"
  ln -s "$victim_src" "$victim_link"
  printf 'skill=../victim-link\n' >>"$home/.claude/skills/.agent-mail-manifest-v1"
  env -i HOME="$home" PATH="$bin_dir" LC_ALL=C TMPDIR="$TMPDIR" \
    AGENT_MAIL_PKGSHARE="$am_share" \
    "$shell_bin" "$MULTI_SCRIPT" --tool agent-mail --claude >/dev/null
  [[ -L "$victim_link" ]]

  # 7. Unknown --tool exits 2 without modifying files.
  local bad_rc=0
  env -i HOME="$home" PATH="$bin_dir" LC_ALL=C TMPDIR="$TMPDIR" \
    "$shell_bin" "$MULTI_SCRIPT" --tool bogus >/dev/null 2>&1 || bad_rc=$?
  [[ "$bad_rc" -eq 2 ]]

  # 8. Atomic pre-check refuses clobbering a non-symlink skill directory without half-installing earlier skills.
  mkdir -p "$acli_share/skills/acli-alpha" "$acli_share/skills/acli-zeta"
  printf -- '---\nname: acli-alpha\n---\n# Alpha\n' >"$acli_share/skills/acli-alpha/SKILL.md"
  printf -- '---\nname: acli-zeta\n---\n# Zeta\n' >"$acli_share/skills/acli-zeta/SKILL.md"
  rm -rf "$home/.qwen/skills"
  mkdir -p "$home/.qwen/skills/acli-zeta"
  local clobber_rc=0
  env -i HOME="$home" PATH="$bin_dir" LC_ALL=C TMPDIR="$TMPDIR" \
    ACLI_PKGSHARE="$acli_share" \
    "$shell_bin" "$MULTI_SCRIPT" --tool acli --qwen >/dev/null 2>&1 || clobber_rc=$?
  [[ "$clobber_rc" -ne 0 ]]
  [[ -d "$home/.qwen/skills/acli-zeta" && ! -L "$home/.qwen/skills/acli-zeta" ]]
  [[ ! -e "$home/.qwen/skills/acli-alpha" && ! -L "$home/.qwen/skills/acli-alpha" ]]
  [[ ! -e "$home/.qwen/skills/.acli-manifest-v1" ]]
}

@test "bash 3.2: multi-tool --tool agent-mail|acli|all across 9 CLIs with zero ripwire dependency" {
  run case_multitool_no_ripwire_all_9_clis "$MULTI_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 5+: multi-tool --tool agent-mail|acli|all across 9 CLIs with zero ripwire dependency" {
  run case_multitool_no_ripwire_all_9_clis "$MULTI_MODERN_BASH"
  [ "$status" -eq 0 ]
}
