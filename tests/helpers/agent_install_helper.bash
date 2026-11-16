# Bats helper for tests/integration_agent_install.bats.
#
# Target contract (artagon-shell/shell-testing/v1):
# - Language: Bash 3.2+ sourced Bats helper.
# - Role: Sourced test harness helper (`load helpers/agent_install_helper`); executes
#   both Ripwire installer entrypoints (`Formula/ripwire.rb` Ruby-evaluated wrapper
#   and standalone `scripts/install-agent-skills.sh`) explicitly under both Bash 3.2
#   (`BATS_BASH32`) and Bash 5+ (`BATS_MODERN_BASH`).
# - State: Isolates all side effects inside `BATS_FILE_TMPDIR` and `BATS_TEST_TMPDIR`;
#   never reads or mutates live `HOME`, agent executables, or user hook configs.
# - Platform: macOS BSD and Linux GNU userland; requires awk, cmp, cp, diff, env,
#   find, grep, jq, mktemp, mv, readlink, rm, ruby, shasum/sha256sum, sort, wc.
# shellcheck shell=bash disable=SC2310,SC2312

readonly INSTALLER_SHA256="9f509a349565a35d1d1b38740906fad8f225fbba8a5822699df41e5ec75efe85"
readonly AGENT_TARGET_NAMES=(claude codex agy kimi grok copilot shared)
readonly AGENT_ISOLATED_COMMANDS=(basename dirname mkdir grep rm ln mktemp mv chmod cat jq cp readlink find diff cmp)
readonly AGENT_ALL_DEST_RELPATHS=(
  ".claude/skills"
  ".agents/skills"
  ".gemini/antigravity-cli/skills"
  ".kimi-code/skills"
  ".grok/skills"
  ".copilot/skills"
)

agent_sha256_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$path" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$path" | awk '{ print $1 }'
  else
    openssl dgst -sha256 "$path" | awk '{ print $NF }'
  fi
}

agent_target_relpath() {
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

agent_snapshot_tree() {
  local dir="$1"
  local out_manifest="$2"
  : >"$out_manifest"
  local p="" rel=""
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    rel="${p#"$dir/"}"
    if [[ -L "$p" ]]; then
      printf 'L\t%s\t%s\n' "$rel" "$(readlink "$p")" >>"$out_manifest"
    elif [[ -f "$p" ]]; then
      printf 'F\t%s\t%s\n' "$rel" "$(agent_sha256_file "$p")" >>"$out_manifest"
    elif [[ -d "$p" ]]; then
      printf 'D\t%s\n' "$rel" >>"$out_manifest"
    fi
  done < <(find "$dir" -mindepth 1 -print | LC_ALL=C sort)
}

agent_setup_file_shared() {
  export AGENT_BASH32="${BATS_BASH32:-/bin/bash}"
  export AGENT_MODERN_BASH="${BATS_MODERN_BASH:-$(command -v bash)}"
  export AGENT_REPO_ROOT="${BATS_REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)}"
  export AGENT_PKGSHARE_SRC="${BATS_RIPWIRE_PKGSHARE:-/opt/homebrew/opt/ripwire/share/ripwire}"
  export AGENT_HAS_BASH32=0

  [[ -x "$AGENT_MODERN_BASH" ]] || {
    printf 'Missing Bash 5+ interpreter: %s\n' "$AGENT_MODERN_BASH" >&2
    return 1
  }

  local mod_ver=""
  mod_ver="$("$AGENT_MODERN_BASH" --version | awk 'NR == 1 { print; exit }')"
  [[ "$mod_ver" =~ version\ [5-9]\. ]] || {
    printf 'BATS_MODERN_BASH must identify Bash 5+ (got: %s)\n' "$mod_ver" >&2
    return 1
  }

  local b32_ver=""
  if [[ -x "$AGENT_BASH32" ]]; then
    b32_ver="$("$AGENT_BASH32" --version | awk 'NR == 1 { print; exit }')"
  fi
  if [[ "$b32_ver" =~ version\ 3\.2\. ]]; then
    AGENT_HAS_BASH32=1
  elif [[ "$(uname -s)" = "Darwin" ]]; then
    printf 'BATS_BASH32 must identify Bash 3.2 on Darwin (got: %s)\n' "${b32_ver:-missing}" >&2
    return 1
  fi

  export AGENT_ENV_BIN AGENT_RUBY_BIN
  AGENT_ENV_BIN="$(command -v env)"
  AGENT_RUBY_BIN="$(command -v ruby || true)"
  if [[ -z "$AGENT_RUBY_BIN" ]] && command -v brew >/dev/null 2>&1; then
    AGENT_RUBY_BIN="$(brew --repo)/Library/Homebrew/vendor/portable-ruby/current/bin/ruby"
  fi
  [[ -x "$AGENT_RUBY_BIN" ]] || {
    printf 'Missing ruby interpreter for formula wrapper extraction\n' >&2
    return 1
  }

  [[ -d "$AGENT_PKGSHARE_SRC" ]] || {
    printf 'Requires the unmodified Ripwire 0.6.10 bundled installer at %s\n' "$AGENT_PKGSHARE_SRC" >&2
    return 1
  }
  local orig_pkgshare=""
  orig_pkgshare="$(cd "$AGENT_PKGSHARE_SRC" && pwd -P)"
  local installer_file="$orig_pkgshare/skills/install.sh"
  [[ -f "$installer_file" && "$(agent_sha256_file "$installer_file")" = "$INSTALLER_SHA256" ]] || {
    printf 'Requires the unmodified Ripwire 0.6.10 bundled installer (%s)\n' "$INSTALLER_SHA256" >&2
    return 1
  }

  export AGENT_SHARED_ROOT="$BATS_FILE_TMPDIR/agent-shared"
  mkdir -p "$AGENT_SHARED_ROOT/cmd-bin"

  export AGENT_PAYLOAD_DIR="$AGENT_SHARED_ROOT/payload"
  cp -RL "$orig_pkgshare" "$AGENT_PAYLOAD_DIR"
  AGENT_PAYLOAD_DIR="$(cd "$AGENT_PAYLOAD_DIR" && pwd -P)"

  export AGENT_EXPECTED_DEFAULT="$AGENT_SHARED_ROOT/expected-default.txt"
  export AGENT_EXPECTED_CONTRIB="$AGENT_SHARED_ROOT/expected-contrib.txt"
  : >"$AGENT_EXPECTED_DEFAULT"
  : >"$AGENT_EXPECTED_CONTRIB"

  local skill_md="" skill_name=""
  for skill_md in "$AGENT_PAYLOAD_DIR/skills"/ripwire-*/SKILL.md; do
    [[ -f "$skill_md" ]] || continue
    skill_name="$(basename "$(dirname "$skill_md")")"
    printf '%s\n' "$skill_name" >>"$AGENT_EXPECTED_CONTRIB"
    if ! grep -Eq '^audience: contributor$' "$skill_md"; then
      printf '%s\n' "$skill_name" >>"$AGENT_EXPECTED_DEFAULT"
    fi
  done
  sort -u "$AGENT_EXPECTED_DEFAULT" -o "$AGENT_EXPECTED_DEFAULT"
  sort -u "$AGENT_EXPECTED_CONTRIB" -o "$AGENT_EXPECTED_CONTRIB"

  local def_cnt="" con_cnt=""
  def_cnt="$(wc -l <"$AGENT_EXPECTED_DEFAULT" | awk '{ print $1 }')"
  con_cnt="$(wc -l <"$AGENT_EXPECTED_CONTRIB" | awk '{ print $1 }')"
  [[ "$def_cnt" -eq 16 && "$con_cnt" -eq 17 ]] || {
    printf 'Unexpected pinned payload skill counts: default=%s contrib=%s\n' "$def_cnt" "$con_cnt" >&2
    return 1
  }

  export AGENT_FORMULA_SNAPSHOT="$AGENT_SHARED_ROOT/ripwire.rb"
  export AGENT_STANDALONE_ENTRY="$AGENT_SHARED_ROOT/install-agent-skills.sh"
  export AGENT_FORMULA_ENTRY="$AGENT_SHARED_ROOT/ripwire-agent-install"
  cp "$AGENT_REPO_ROOT/Formula/ripwire.rb" "$AGENT_FORMULA_SNAPSHOT"
  cp "$AGENT_REPO_ROOT/scripts/install-agent-skills.sh" "$AGENT_STANDALONE_ENTRY"
  chmod 0755 "$AGENT_STANDALONE_ENTRY"

  "$AGENT_RUBY_BIN" -EUTF-8:UTF-8 -e '
    source = File.read(ARGV[0])
    match = source.match(/\(bin\/"ripwire-agent-install"\)\.write (<<~SHELL\n.*?^    SHELL\n)/m)
    abort "Cannot locate formula wrapper heredoc" unless match
    opt_pkgshare = ARGV[1]
    print eval(match[1], binding, ARGV[0])
  ' "$AGENT_FORMULA_SNAPSHOT" "$AGENT_PAYLOAD_DIR" >"$AGENT_FORMULA_ENTRY"
  chmod 0755 "$AGENT_FORMULA_ENTRY"

  local cmd_name="" resolved=""
  for cmd_name in "${AGENT_ISOLATED_COMMANDS[@]}"; do
    resolved="$(command -v "$cmd_name")"
    ln -s "$resolved" "$AGENT_SHARED_ROOT/cmd-bin/$cmd_name"
  done
}

agent_setup_case_root() {
  local shell_bin="$1"
  local root="$BATS_TEST_TMPDIR/case"
  rm -rf -- "$root"
  mkdir -p "$root/home" "$root/bin" "$root/tmp"
  local link=""
  for link in "$AGENT_SHARED_ROOT/cmd-bin"/*; do
    ln -s "$(readlink "$link")" "$root/bin/$(basename "$link")"
  done
  ln -s "$shell_bin" "$root/bin/bash"
  printf '%s\n' "$root"
}

agent_invoke_entry() {
  local root="$1"
  local shell_bin="$2"
  local entry_path="$3"
  local agy_override="$4"
  shift 4

  local out_file="$root/last.out"
  local err_file="$root/last.err"
  local -a env_args=(
    "HOME=$root/home"
    "PATH=$root/bin"
    "LC_ALL=C"
    "TMPDIR=$root/tmp"
    "RIPWIRE_PKGSHARE=$AGENT_PAYLOAD_DIR"
  )
  if [[ -n "$agy_override" ]]; then
    env_args+=("AGY_SKILLS_DIR=$agy_override")
  fi

  local rc=0
  (
    cd "$root/home" \
      && "$AGENT_ENV_BIN" -i "${env_args[@]}" "$shell_bin" "$entry_path" "$@"
  ) >"$out_file" 2>"$err_file" || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    cat "$err_file" >&2
    return "$rc"
  fi
  cat "$out_file"
}

agent_assert_no_hooks() {
  local home="$1"
  [[ ! -e "$home/.claude/settings.json" && ! -L "$home/.claude/settings.json" ]]
  [[ ! -e "$home/.codex/hooks.json" && ! -L "$home/.codex/hooks.json" ]]
}

agent_verify_skills() {
  local destination="$1"
  local contributor="$2"
  local manifest="$destination/.ripwire-manifest-v1"
  [[ -f "$manifest" ]]
  [[ "$(awk 'NR == 1 { print; exit }' "$manifest")" = "version=1" ]]

  local expected_file="$AGENT_EXPECTED_DEFAULT"
  if [[ "$contributor" -eq 1 ]]; then
    expected_file="$AGENT_EXPECTED_CONTRIB"
  fi

  local tmp_actual="$BATS_TEST_TMPDIR/.actual-manifest"
  local tmp_actual_sorted="$BATS_TEST_TMPDIR/.actual-manifest-sorted"
  local tmp_installed="$BATS_TEST_TMPDIR/.installed-skills"

  awk 'NR > 1 { sub(/^skill=/, ""); print }' "$manifest" >"$tmp_actual"
  sort "$tmp_actual" >"$tmp_actual_sorted"
  local raw_lines="" uniq_lines=""
  raw_lines="$(wc -l <"$tmp_actual" | awk '{ print $1 }')"
  uniq_lines="$(sort -u "$tmp_actual" | wc -l | awk '{ print $1 }')"
  [[ "$raw_lines" -eq "$uniq_lines" ]]
  cmp -s "$tmp_actual_sorted" "$expected_file"

  : >"$tmp_installed"
  local s_path=""
  for s_path in "$destination"/ripwire-*; do
    [[ -e "$s_path" || -L "$s_path" ]] || continue
    basename "$s_path" >>"$tmp_installed"
  done
  sort -u "$tmp_installed" -o "$tmp_installed"
  cmp -s "$tmp_installed" "$expected_file"

  local skill="" link="" resolved=""
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    link="$destination/$skill"
    [[ -L "$link" ]] || return 1
    resolved="$(cd "$link" 2>/dev/null && pwd -P)"
    [[ "$resolved" = "$AGENT_PAYLOAD_DIR/skills/$skill" ]] || return 1
    [[ -f "$link/SKILL.md" ]] || return 1
  done <"$tmp_actual"
}

case_agent_regression() {
  local entry="$1"
  local shell_bin="$2"
  local kind="$3"

  local root=""
  root="$(agent_setup_case_root "$shell_bin")"
  local home="$root/home"

  case "$kind" in
    default)
      agent_invoke_entry "$root" "$shell_bin" "$entry" "" >/dev/null
      agent_verify_skills "$home/.agents/skills" 0
      ;;
    custom_agy)
      local custom="$home/custom agy skills"
      mkdir -p "$custom"
      agent_snapshot_tree "$home" "$root/before.tree"
      local listing=""
      listing="$(agent_invoke_entry "$root" "$shell_bin" "$entry" "$custom" --list)"
      printf '%s\n' "$listing" | grep -Eq '^[[:space:]]*agy[[:space:]]+installed[[:space:]]+'
      [[ "$listing" == *"$custom"* ]]
      agent_snapshot_tree "$home" "$root/after-list.tree"
      cmp -s "$root/before.tree" "$root/after-list.tree"
      agent_invoke_entry "$root" "$shell_bin" "$entry" "$custom" >/dev/null
      agent_verify_skills "$custom" 0
      agent_invoke_entry "$root" "$shell_bin" "$entry" "$custom" --all --contributor >/dev/null
      agent_verify_skills "$custom" 1
      [[ ! -e "$home/.gemini" ]]
      agent_assert_no_hooks "$home"
      ;;
    shared_hook)
      mkdir -p "$home/.agents"
      agent_invoke_entry "$root" "$shell_bin" "$entry" "" --hook >/dev/null
      [[ ! -e "$home/.codex" ]]
      [[ ! -e "$home/.claude" ]]
      agent_verify_skills "$home/.agents/skills" 0
      ;;
    *)
      return 1
      ;;
  esac
}

case_agent_install_matrix() {
  local entry="$1"
  local shell_bin="$2"
  local target="$3"
  local contributor="$4"

  local root=""
  root="$(agent_setup_case_root "$shell_bin")"
  local home="$root/home"

  local -a call_args=("$root" "$shell_bin" "$entry" "")
  local -a selected_rels=()
  if [[ "$target" = "default" ]]; then
    selected_rels=(".agents/skills")
  elif [[ "$target" = "all" ]]; then
    call_args+=("--all")
    mkdir -p "$home/.claude" "$home/.codex" "$home/.gemini" \
      "$home/.kimi-code" "$home/.grok" "$home/.copilot"
    selected_rels=("${AGENT_ALL_DEST_RELPATHS[@]}")
  else
    call_args+=("--$target")
    local rel=""
    rel="$(agent_target_relpath "$target")"
    selected_rels=("$rel")
  fi

  local -a non_contrib_args=("${call_args[@]}")
  if [[ "$contributor" -eq 1 ]]; then
    call_args+=("--contributor")
  fi

  agent_invoke_entry "${call_args[@]}" >/dev/null

  local sel=""
  for sel in "${selected_rels[@]}"; do
    agent_verify_skills "$home/$sel" "$contributor"
  done

  local candidate="" is_selected=0
  for candidate in "${AGENT_ALL_DEST_RELPATHS[@]}"; do
    is_selected=0
    for sel in "${selected_rels[@]}"; do
      if [[ "$candidate" = "$sel" ]]; then
        is_selected=1
        break
      fi
    done
    if [[ "$is_selected" -eq 0 && -e "$home/$candidate" ]]; then
      return 1
    fi
  done

  agent_assert_no_hooks "$home"

  agent_snapshot_tree "$home" "$root/before.tree"
  agent_invoke_entry "${call_args[@]}" >/dev/null
  agent_snapshot_tree "$home" "$root/after.tree"
  cmp -s "$root/before.tree" "$root/after.tree"

  if [[ "$contributor" -eq 1 ]]; then
    agent_invoke_entry "${non_contrib_args[@]}" >/dev/null
    for sel in "${selected_rels[@]}"; do
      agent_verify_skills "$home/$sel" 0
    done
  fi
}

case_agent_hook_install() {
  local entry="$1"
  local shell_bin="$2"
  local target="$3"
  local contributor="$4"

  local root=""
  root="$(agent_setup_case_root "$shell_bin")"
  local home="$root/home"

  local config_rel=".codex/hooks.json"
  local opposite_rel=".claude/settings.json"
  if [[ "$target" = "claude" ]]; then
    config_rel=".claude/settings.json"
    opposite_rel=".codex/hooks.json"
  fi
  local config_file="$home/$config_rel"
  mkdir -p "$(dirname "$config_file")"
  cat >"$config_file" <<'JSON'
{"existing_setting":"preserve-me","hooks":{"PreToolUse":[{"matcher":"other","hooks":[{"type":"command","command":"echo preserved"}]}]}}
JSON

  local -a flags=("--$target" "--hook")
  if [[ "$contributor" -eq 1 ]]; then
    flags+=("--contributor")
  fi

  agent_invoke_entry "$root" "$shell_bin" "$entry" "" "${flags[@]}" >/dev/null
  local skill_rel=""
  skill_rel="$(agent_target_relpath "$target")"
  agent_verify_skills "$home/$skill_rel" "$contributor"

  jq -e \
    --arg hooks_dir "$AGENT_PAYLOAD_DIR/hooks" \
    --argjson root "$(cat "$config_file")" \
    '
      .existing_setting == "preserve-me"
      and .hooks.PreToolUse[0].hooks[0].command == "echo preserved"
      and (
        ["PreToolUse", "SessionStart", "UserPromptSubmit"]
        | all(
            . as $ev
            | ([ $root.hooks[$ev][]?.hooks[]? | select(.command | contains($hooks_dir)) ] | length == 1)
          )
      )
    ' "$config_file" >/dev/null

  [[ ! -e "$home/$opposite_rel" ]]

  agent_snapshot_tree "$home" "$root/before.tree"
  agent_invoke_entry "$root" "$shell_bin" "$entry" "" "${flags[@]}" >/dev/null
  agent_snapshot_tree "$home" "$root/after.tree"
  cmp -s "$root/before.tree" "$root/after.tree"
}

case_agent_cli_contract() {
  local entry="$1"
  local shell_bin="$2"

  local root=""
  root="$(agent_setup_case_root "$shell_bin")"
  local home="$root/home"

  agent_snapshot_tree "$home" "$root/before.tree"
  local help_text=""
  help_text="$(agent_invoke_entry "$root" "$shell_bin" "$entry" "" --help)"
  local t=""
  for t in "${AGENT_TARGET_NAMES[@]}"; do
    [[ "$help_text" == *"--$t"* ]] || return 1
  done

  local listing=""
  listing="$(agent_invoke_entry "$root" "$shell_bin" "$entry" "" --list)"
  for t in claude codex agy kimi grok copilot; do
    printf '%s\n' "$listing" | grep -Eq "^[[:space:]]*${t}[[:space:]]+not found[[:space:]]+" || return 1
  done

  local bad_rc=0
  (
    cd "$home" \
      && "$AGENT_ENV_BIN" -i \
        "HOME=$home" \
        "PATH=$root/bin" \
        "LC_ALL=C" \
        "TMPDIR=$root/tmp" \
        "RIPWIRE_PKGSHARE=$AGENT_PAYLOAD_DIR" \
        "$shell_bin" "$entry" --invalid-integration-flag
  ) >"$root/bad.out" 2>"$root/bad.err" || bad_rc=$?

  [[ "$bad_rc" -eq 2 ]]
  grep -Fq "Unknown option" "$root/bad.err"

  agent_snapshot_tree "$home" "$root/after.tree"
  cmp -s "$root/before.tree" "$root/after.tree"
}
