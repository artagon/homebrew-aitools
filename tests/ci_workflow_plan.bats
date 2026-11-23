#!/usr/bin/env bats
# Bats behavior and compatibility suite for scripts/ci/plan-ci.sh and
# scripts/ci/merge-provenance-shards.sh (`artagon-shell/shell-testing/v1`).
#
# Executes every target contract explicitly under both stock macOS Bash 3.2
# (`BATS_BASH32`) and modern Bash 5+ (`BATS_MODERN_BASH`) in isolated git repos
# and temp directories inside `$BATS_TEST_TMPDIR`.

setup_file() {
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  export PLAN_BASH32="${BATS_BASH32:-/bin/bash}"
  export PLAN_MODERN_BASH="${BATS_MODERN_BASH:-$(command -v bash)}"
  export PLAN_REPO_ROOT="${BATS_REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)}"
  export PLAN_SCRIPT="$PLAN_REPO_ROOT/scripts/ci/plan-ci.sh"
  export MERGE_SCRIPT="$PLAN_REPO_ROOT/scripts/ci/merge-provenance-shards.sh"
  export PLAN_HAS_BASH32=0

  [[ -x "$PLAN_SCRIPT" ]] || {
    printf 'Missing executable plan script: %s\n' "$PLAN_SCRIPT" >&2
    return 1
  }
  [[ -x "$MERGE_SCRIPT" ]] || {
    printf 'Missing executable merge script: %s\n' "$MERGE_SCRIPT" >&2
    return 1
  }
  [[ -x "$PLAN_MODERN_BASH" ]] || {
    printf 'Missing Bash 5+ interpreter: %s\n' "$PLAN_MODERN_BASH" >&2
    return 1
  }

  local mod_ver=""
  mod_ver="$("$PLAN_MODERN_BASH" --version | awk 'NR == 1 { print; exit }')"
  [[ "$mod_ver" =~ version\ [5-9]\. ]] || {
    printf 'BATS_MODERN_BASH must identify Bash 5+ (got: %s)\n' "$mod_ver" >&2
    return 1
  }

  local b32_ver=""
  if [[ -x "$PLAN_BASH32" ]]; then
    b32_ver="$("$PLAN_BASH32" --version | awk 'NR == 1 { print; exit }')"
  fi
  if [[ "$b32_ver" =~ version\ 3\.2\. ]]; then
    PLAN_HAS_BASH32=1
  elif [[ "$(uname -s)" = "Darwin" ]]; then
    printf 'BATS_BASH32 must identify Bash 3.2 on Darwin (got: %s)\n' "${b32_ver:-missing}" >&2
    return 1
  fi
}

setup() {
  if [[ "$BATS_TEST_DESCRIPTION" == "bash 3.2:"* ]] && [[ "${PLAN_HAS_BASH32:-0}" -ne 1 ]]; then
    skip "macOS Bash 3.2 interpreter is not installed on $(uname -s)"
  fi
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  export HOME="$BATS_TEST_TMPDIR/home"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$HOME" "$TMPDIR"
}

sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$path" | awk '{ print $1 }'
  else
    shasum -a 256 -- "$path" | awk '{ print $1 }'
  fi
}

init_test_repo() {
  local repo="$1"
  rm -rf -- "$repo"
  mkdir -p "$repo/Formula" "$repo/scripts/ci" "$repo/tests" "$repo/.github/workflows"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.name "Test Bot"
  git -C "$repo" config user.email "test-bot@example.invalid"

  cat >"$repo/README.md" <<'EOF'
# Test Tap
EOF
  cat >"$repo/ABOUT.md" <<'EOF'
# About
EOF
  cat >"$repo/Formula/base.rb" <<'EOF'
class Base < Formula
  desc "Base formula"
  url "https://example.invalid/base-1.0.0.tar.gz"
  sha256 "1111111111111111111111111111111111111111111111111111111111111111"
  license "MIT"
end
EOF
  cat >"$repo/Formula/foo.rb" <<'EOF'
class Foo < Formula
  desc "Foo formula"
  url "https://example.invalid/foo-1.0.0.tar.gz"
  sha256 "2222222222222222222222222222222222222222222222222222222222222222"
  license "MIT"
end
EOF
  cat >"$repo/Formula/old.rb" <<'EOF'
class Old < Formula
  desc "Old formula"
  url "https://example.invalid/old-1.0.0.tar.gz"
  sha256 "3333333333333333333333333333333333333333333333333333333333333333"
  license "MIT"
end
EOF
  cat >"$repo/Formula/tree-sitter-java-valhalla.rb" <<'EOF'
class TreeSitterJavaValhalla < Formula
  desc "Valhalla Java grammar"
  url "https://example.invalid/tsjv-1.0.0.tar.gz"
  sha256 "4444444444444444444444444444444444444444444444444444444444444444"
  license "MIT"
end
EOF
  cat >"$repo/Formula/ast-grep-valhalla.rb" <<'EOF'
class AstGrepValhalla < Formula
  desc "ast-grep with Valhalla grammar"
  url "https://example.invalid/agv-1.0.0.tar.gz"
  sha256 "5555555555555555555555555555555555555555555555555555555555555555"
  license "MIT"

  depends_on "artagon/aitools/tree-sitter-java-valhalla" => :build
end
EOF
  cat >"$repo/Formula/ripwire.rb" <<'EOF'
class Ripwire < Formula
  desc "Ripwire"
  url "https://example.invalid/ripwire-1.0.0.tar.gz"
  sha256 "6666666666666666666666666666666666666666666666666666666666666666"
  license "MIT"

  depends_on "artagon/aitools/tree-sitter-java-valhalla" => :build
end
EOF
  cat >"$repo/scripts/install-agent-skills.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
  cat >"$repo/scripts/ci/plan-ci.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "initial commit"
  git -C "$repo" update-ref refs/remotes/origin/main HEAD
}

get_output_value() {
  local out_file="$1"
  local key="$2"
  awk -F '=' -v k="$key" '$1 == k { print substr($0, length(k) + 2); found = 1; exit } END { if (!found) exit 1 }' "$out_file"
}

assert_output_eq() {
  local out_file="$1"
  local key="$2"
  local expected="$3"
  local actual=""
  actual="$(get_output_value "$out_file" "$key")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Output mismatch for %s: expected [%s], got [%s]\n' "$key" "$expected" "$actual" >&2
    return 1
  fi
}

run_plan_in_repo() {
  local shell_bin="$1"
  local repo="$2"
  local out_file="$3"
  shift 3
  : >"$out_file"
  (
    cd "$repo" || exit 1
    env "$@" GITHUB_OUTPUT="$out_file" "$shell_bin" "$PLAN_SCRIPT"
  )
}

case_docs_only_pr() {
  local shell_bin="$1"
  local repo="$BATS_TEST_TMPDIR/repo-docs"
  local out="$BATS_TEST_TMPDIR/out-docs.txt"
  init_test_repo "$repo"
  local base_sha="" head_sha=""
  base_sha="$(git -C "$repo" rev-parse HEAD)"

  printf '\nUpdated README.\n' >>"$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "docs: update README"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  run_plan_in_repo "$shell_bin" "$repo" "$out" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"

  assert_output_eq "$out" has_formulae "false"
  assert_output_eq "$out" shard_count "0"
  assert_output_eq "$out" use_merge "false"
  assert_output_eq "$out" include_macos "false"
  assert_output_eq "$out" matrix_oses_json '["ubuntu-24.04","ubuntu-24.04-arm"]'
  assert_output_eq "$out" shards_json "[]"
  assert_output_eq "$out" changed_style_files_json "[]"
  assert_output_eq "$out" needs_homebrew_in_lint "false"
  assert_output_eq "$out" run_readme_check "true"
  assert_output_eq "$out" run_tap_docs_check "true"
  assert_output_eq "$out" run_lint_job "true"
  assert_output_eq "$out" run_brew_style "false"
  assert_output_eq "$out" run_brew_readall "false"
  assert_output_eq "$out" run_brew_audit_tap "false"
  assert_output_eq "$out" run_ast_grep "false"
  assert_output_eq "$out" run_bats_lint "false"
  assert_output_eq "$out" run_provenance_bats "false"
  assert_output_eq "$out" run_cask_bats "false"
  assert_output_eq "$out" run_installer_bats_standalone "false"

  # ABOUT.md change runs tap-docs check without Homebrew or bottle provenance checks.
  local out_about="$BATS_TEST_TMPDIR/out-about.txt"
  git -C "$repo" checkout -q -b about-pr "$base_sha"
  printf '\nUpdated ABOUT.\n' >>"$repo/ABOUT.md"
  git -C "$repo" add ABOUT.md
  git -C "$repo" commit -q -m "docs: update ABOUT"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  run_plan_in_repo "$shell_bin" "$repo" "$out_about" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"

  assert_output_eq "$out_about" has_formulae "false"
  assert_output_eq "$out_about" run_lint_job "true"
  assert_output_eq "$out_about" needs_homebrew_in_lint "false"
  assert_output_eq "$out_about" run_readme_check "false"
  assert_output_eq "$out_about" run_tap_docs_check "true"

  # Non-inventory doc change skips the entire lint job as well.
  local out_other_doc="$BATS_TEST_TMPDIR/out-other-doc.txt"
  git -C "$repo" checkout -q -b other-doc-pr "$base_sha"
  mkdir -p "$repo/docs"
  printf '# Notes\n' >"$repo/docs/notes.md"
  git -C "$repo" add docs/notes.md
  git -C "$repo" commit -q -m "docs: add notes"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  run_plan_in_repo "$shell_bin" "$repo" "$out_other_doc" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"

  assert_output_eq "$out_other_doc" has_formulae "false"
  assert_output_eq "$out_other_doc" run_lint_job "false"
  assert_output_eq "$out_other_doc" needs_homebrew_in_lint "false"
  assert_output_eq "$out_other_doc" run_readme_check "false"
  assert_output_eq "$out_other_doc" run_tap_docs_check "false"
  assert_output_eq "$out_other_doc" run_lock_check "false"

  # versions/* change triggers lint + run_lock_check without Homebrew setup or bottle builds.
  local out_versions="$BATS_TEST_TMPDIR/out-versions.txt"
  git -C "$repo" checkout -q -b versions-pr "$base_sha"
  mkdir -p "$repo/versions"
  printf '{"schema":"artagon-aitools-lock/v1"}\n' >"$repo/versions/aitools-lock.json"
  git -C "$repo" add versions/aitools-lock.json
  git -C "$repo" commit -q -m "chore: update versions lock"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  run_plan_in_repo "$shell_bin" "$repo" "$out_versions" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"

  assert_output_eq "$out_versions" has_formulae "false"
  assert_output_eq "$out_versions" run_lint_job "true"
  assert_output_eq "$out_versions" needs_homebrew_in_lint "false"
  assert_output_eq "$out_versions" run_lock_check "true"
  assert_output_eq "$out_versions" require_lockfile "true"
  assert_output_eq "$out_versions" run_brew_style "false"
  assert_output_eq "$out_versions" run_tap_docs_check "false"

  # Deleting versions/aitools-lock.json must fail closed (require_lockfile=true + run_lock_check=true).
  local del_base="" del_head=""
  del_base="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" rm -q versions/aitools-lock.json
  git -C "$repo" commit -q -m "remove lockfile"
  del_head="$(git -C "$repo" rev-parse HEAD)"

  local out_del_lock="$BATS_TEST_TMPDIR/out-del-lock.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_del_lock" \
    EVENT_NAME=pull_request BASE_SHA="$del_base" HEAD_SHA="$del_head"
  assert_output_eq "$out_del_lock" run_lint_job "true"
  assert_output_eq "$out_del_lock" run_lock_check "true"
  assert_output_eq "$out_del_lock" require_lockfile "true"
}

case_single_formula_pr_and_validation() {
  local shell_bin="$1"
  local repo="$BATS_TEST_TMPDIR/repo-single"
  local out="$BATS_TEST_TMPDIR/out-single.txt"
  init_test_repo "$repo"
  local base_sha="" head_sha=""
  base_sha="$(git -C "$repo" rev-parse HEAD)"

  printf '# bump\n' >>"$repo/Formula/foo.rb"
  git -C "$repo" add Formula/foo.rb
  git -C "$repo" commit -q -m "foo: bump"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  run_plan_in_repo "$shell_bin" "$repo" "$out" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"

  assert_output_eq "$out" has_formulae "true"
  assert_output_eq "$out" shard_count "1"
  assert_output_eq "$out" use_merge "false"
  assert_output_eq "$out" include_macos "false"
  assert_output_eq "$out" matrix_oses_json '["ubuntu-24.04","ubuntu-24.04-arm"]'
  assert_output_eq "$out" has_intra_tap_runtime_deps "false"
  assert_output_eq "$out" deleted_formulae ""
  assert_output_eq "$out" changed_style_files_json '["Formula/foo.rb"]'
  assert_output_eq "$out" run_brew_style "true"
  assert_output_eq "$out" run_brew_readall "true"
  assert_output_eq "$out" run_brew_audit_tap "false"
  assert_output_eq "$out" run_ast_grep "true"
  assert_output_eq "$out" run_bats_lint "false"
  assert_output_eq "$out" run_provenance_bats "true"
  assert_output_eq "$out" run_cask_bats "false"
  assert_output_eq "$out" run_installer_bats_standalone "false"
  assert_output_eq "$out" run_readme_check "false"
  assert_output_eq "$out" run_tap_docs_check "false"
  assert_output_eq "$out" run_lock_check "true"
  assert_output_eq "$out" require_lockfile "false"
  assert_output_eq "$out" needs_homebrew_in_lint "true"
  assert_output_eq "$out" run_lint_job "true"

  # Opting into macOS bottles via the PR label adds macos-26 to matrix_oses_json.
  local out_macos_lbl="$BATS_TEST_TMPDIR/out-single-macos-lbl.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_macos_lbl" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha" \
    PR_LABELS_JSON='["enhancement","build-macos-bottles"]'
  assert_output_eq "$out_macos_lbl" include_macos "true"
  assert_output_eq "$out_macos_lbl" matrix_oses_json '["macos-26","ubuntu-24.04","ubuntu-24.04-arm"]'

  # Unrelated PR labels keep Linux-only matrix.
  local out_other_lbl="$BATS_TEST_TMPDIR/out-single-other-lbl.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_other_lbl" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha" \
    PR_LABELS_JSON='["documentation"]'
  assert_output_eq "$out_other_lbl" include_macos "false"
  assert_output_eq "$out_other_lbl" matrix_oses_json '["ubuntu-24.04","ubuntu-24.04-arm"]'

  # Malformed PR_LABELS_JSON fails closed.
  local out_bad_lbl="$BATS_TEST_TMPDIR/out-bad-lbl.txt"
  if run_plan_in_repo "$shell_bin" "$repo" "$out_bad_lbl" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha" \
    PR_LABELS_JSON='{"not":"an-array"}' 2>/dev/null; then
    printf 'Expected failure on non-array PR_LABELS_JSON\n' >&2
    return 1
  fi

  local shards=""
  shards="$(get_output_value "$out" shards_json)"
  jq -e '
    length == 1
    and .[0].id == "shard-1"
    and .[0].formulae == "artagon/aitools/foo"
    and .[0].added == ""
    and .[0].has_ripwire == false
  ' <<<"$shards" >/dev/null

  # Deleting Formula/old.rb + adding Formula/newpkg.rb sets added & deleted properly.
  git -C "$repo" rm -q Formula/old.rb
  cat >"$repo/Formula/newpkg.rb" <<'EOF'
class Newpkg < Formula
  desc "New package"
  url "https://example.invalid/newpkg-1.0.0.tar.gz"
  sha256 "7777777777777777777777777777777777777777777777777777777777777777"
  license "MIT"
end
EOF
  git -C "$repo" add Formula/newpkg.rb
  git -C "$repo" commit -q -m "add newpkg and delete old"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  local out2="$BATS_TEST_TMPDIR/out-single-add-del.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out2" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"

  assert_output_eq "$out2" deleted_formulae "artagon/aitools/old"
  assert_output_eq "$out2" changed_style_files_json '["Formula/foo.rb","Formula/newpkg.rb"]'
  shards="$(get_output_value "$out2" shards_json)"
  jq -e '
    length == 2
    and ([.[].added] | map(select(length > 0)) == ["artagon/aitools/newpkg"])
  ' <<<"$shards" >/dev/null

  # Unexpected file under Formula/ fails closed.
  printf 'not a formula\n' >"$repo/Formula/README.md"
  git -C "$repo" add Formula/README.md
  git -C "$repo" commit -q -m "bad file in Formula/"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  local out_bad="$BATS_TEST_TMPDIR/out-bad-formula.txt"
  if run_plan_in_repo "$shell_bin" "$repo" "$out_bad" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha" 2>/dev/null; then
    printf 'Expected failure on Formula/README.md\n' >&2
    return 1
  fi
}

case_multi_formula_capped_5_shards() {
  local shell_bin="$1"
  local repo="$BATS_TEST_TMPDIR/repo-seven"
  local out="$BATS_TEST_TMPDIR/out-seven.txt"
  init_test_repo "$repo"
  local base_sha="" head_sha=""
  base_sha="$(git -C "$repo" rev-parse HEAD)"

  local idx=1
  while [[ "$idx" -le 7 ]]; do
    cat >"$repo/Formula/pkg${idx}.rb" <<EOF
class Pkg${idx} < Formula
  desc "Package ${idx}"
  url "https://example.invalid/pkg${idx}-1.0.0.tar.gz"
  sha256 "111111111111111111111111111111111111111111111111111111111111111${idx}"
  license "MIT"
end
EOF
    idx=$((idx + 1))
  done
  git -C "$repo" add Formula/pkg*.rb
  git -C "$repo" commit -q -m "add 7 independent formulae"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  run_plan_in_repo "$shell_bin" "$repo" "$out" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"

  assert_output_eq "$out" has_formulae "true"
  assert_output_eq "$out" shard_count "5"
  assert_output_eq "$out" use_merge "true"
  assert_output_eq "$out" has_intra_tap_runtime_deps "false"

  local shards=""
  shards="$(get_output_value "$out" shards_json)"
  jq -e '
    length == 5
    and ([.[].id] == ["shard-1","shard-2","shard-3","shard-4","shard-5"])
    and ([.[].formulae | split(",") | length] | sort == [1,1,1,2,2])
    and ([.[].formulae | split(",")[]] | sort == [
      "artagon/aitools/pkg1",
      "artagon/aitools/pkg2",
      "artagon/aitools/pkg3",
      "artagon/aitools/pkg4",
      "artagon/aitools/pkg5",
      "artagon/aitools/pkg6",
      "artagon/aitools/pkg7"
    ])
    and ([.[].added | split(",")[]] | sort == [
      "artagon/aitools/pkg1",
      "artagon/aitools/pkg2",
      "artagon/aitools/pkg3",
      "artagon/aitools/pkg4",
      "artagon/aitools/pkg5",
      "artagon/aitools/pkg6",
      "artagon/aitools/pkg7"
    ])
  ' <<<"$shards" >/dev/null
}

case_intra_tap_dep_grouping() {
  local shell_bin="$1"
  local repo="$BATS_TEST_TMPDIR/repo-group"
  local out="$BATS_TEST_TMPDIR/out-group.txt"
  init_test_repo "$repo"
  local base_sha="" head_sha=""
  base_sha="$(git -C "$repo" rev-parse HEAD)"

  printf '# bump\n' >>"$repo/Formula/tree-sitter-java-valhalla.rb"
  printf '# bump\n' >>"$repo/Formula/ast-grep-valhalla.rb"
  printf '# bump\n' >>"$repo/Formula/ripwire.rb"
  printf '# bump\n' >>"$repo/Formula/foo.rb"
  git -C "$repo" add Formula/tree-sitter-java-valhalla.rb Formula/ast-grep-valhalla.rb Formula/ripwire.rb Formula/foo.rb
  git -C "$repo" commit -q -m "bump valhalla stack and foo"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  run_plan_in_repo "$shell_bin" "$repo" "$out" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"

  assert_output_eq "$out" has_formulae "true"
  assert_output_eq "$out" shard_count "2"
  assert_output_eq "$out" use_merge "true"
  assert_output_eq "$out" has_intra_tap_runtime_deps "false"
  assert_output_eq "$out" run_installer_bats_standalone "false"

  local shards=""
  shards="$(get_output_value "$out" shards_json)"
  jq -e '
    length == 2
    and .[0].id == "shard-1"
    and .[0].formulae == "artagon/aitools/ast-grep-valhalla,artagon/aitools/ripwire,artagon/aitools/tree-sitter-java-valhalla"
    and .[0].has_ripwire == true
    and .[1].id == "shard-2"
    and .[1].formulae == "artagon/aitools/foo"
    and .[1].has_ripwire == false
  ' <<<"$shards" >/dev/null

  # Touching install-agent-skills.sh alongside ripwire keeps standalone=false.
  printf '# update\n' >>"$repo/scripts/install-agent-skills.sh"
  git -C "$repo" add scripts/install-agent-skills.sh
  git -C "$repo" commit -q -m "update installer with ripwire"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  local out_with_rw="$BATS_TEST_TMPDIR/out-inst-with-rw.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_with_rw" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"
  assert_output_eq "$out_with_rw" run_installer_bats_standalone "false"
  assert_output_eq "$out_with_rw" include_macos "false"

  # Touching install-agent-skills.sh WITHOUT ripwire enables standalone=true on Linux lint.
  git -C "$repo" checkout -q -b installer-only "$base_sha"
  printf '# standalone installer fix\n' >>"$repo/scripts/install-agent-skills.sh"
  git -C "$repo" add scripts/install-agent-skills.sh
  git -C "$repo" commit -q -m "update installer standalone"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  local out_standalone="$BATS_TEST_TMPDIR/out-inst-standalone.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_standalone" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"
  assert_output_eq "$out_standalone" has_formulae "false"
  assert_output_eq "$out_standalone" run_installer_bats_standalone "true"
  assert_output_eq "$out_standalone" include_macos "false"

  # Touching a cask enables run_cask_bats without enabling macOS runners.
  git -C "$repo" checkout -q -b cask-only "$base_sha"
  mkdir -p "$repo/Casks"
  printf 'cask "demo" do\nend\n' >"$repo/Casks/demo.rb"
  git -C "$repo" add Casks/demo.rb
  git -C "$repo" commit -q -m "add demo cask"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  local out_cask="$BATS_TEST_TMPDIR/out-cask-only.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_cask" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"
  assert_output_eq "$out_cask" has_formulae "false"
  assert_output_eq "$out_cask" run_cask_bats "true"
  assert_output_eq "$out_cask" run_brew_style "true"
  assert_output_eq "$out_cask" run_brew_readall "true"
  assert_output_eq "$out_cask" run_tap_docs_check "true"
  assert_output_eq "$out_cask" needs_homebrew_in_lint "true"
  assert_output_eq "$out_cask" include_macos "false"
}

case_runtime_dep_detection() {
  local shell_bin="$1"
  local repo="$BATS_TEST_TMPDIR/repo-runtime"
  init_test_repo "$repo"

  cat >"$repo/Formula/consumer.rb" <<'EOF'
class Consumer < Formula
  desc "Runtime consumer of base"
  url "https://example.invalid/consumer-1.0.0.tar.gz"
  sha256 "8888888888888888888888888888888888888888888888888888888888888888"
  license "MIT"

  depends_on "artagon/aitools/base"
end
EOF
  git -C "$repo" add Formula/consumer.rb
  git -C "$repo" commit -q -m "add runtime consumer"
  local base_sha="" head_sha=""
  base_sha="$(git -C "$repo" rev-parse HEAD)"

  # Changing base triggers has_intra_tap_runtime_deps=true (consumer depends on it).
  printf '# bump base\n' >>"$repo/Formula/base.rb"
  git -C "$repo" add Formula/base.rb
  git -C "$repo" commit -q -m "bump base"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  local out_base="$BATS_TEST_TMPDIR/out-rt-base.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_base" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"
  assert_output_eq "$out_base" has_intra_tap_runtime_deps "true"

  # Changing unrelated foo keeps has_intra_tap_runtime_deps=false.
  git -C "$repo" checkout -q -b unrelated "$base_sha"
  printf '# bump foo\n' >>"$repo/Formula/foo.rb"
  git -C "$repo" add Formula/foo.rb
  git -C "$repo" commit -q -m "bump foo"
  head_sha="$(git -C "$repo" rev-parse HEAD)"

  local out_foo="$BATS_TEST_TMPDIR/out-rt-foo.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_foo" \
    EVENT_NAME=pull_request BASE_SHA="$base_sha" HEAD_SHA="$head_sha"
  assert_output_eq "$out_foo" has_intra_tap_runtime_deps "false"
}

case_workflow_dispatch() {
  local shell_bin="$1"
  local repo="$BATS_TEST_TMPDIR/repo-dispatch"
  init_test_repo "$repo"

  # Empty INPUT_FORMULAE on main exits cleanly with has_formulae=false.
  local out_empty="$BATS_TEST_TMPDIR/out-wd-empty.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_empty" \
    EVENT_NAME=workflow_dispatch INPUT_FORMULAE=""
  assert_output_eq "$out_empty" has_formulae "false"
  assert_output_eq "$out_empty" shard_count "0"
  assert_output_eq "$out_empty" use_merge "false"
  assert_output_eq "$out_empty" shards_json "[]"

  # Non-main branch with explicit multi-formula INPUT_FORMULAE + script change.
  git -C "$repo" checkout -q -b bump/multi
  printf '# test edit\n' >>"$repo/scripts/ci/plan-ci.sh"
  git -C "$repo" add scripts/ci/plan-ci.sh
  git -C "$repo" commit -q -m "touch script on bump branch"

  local out_multi="$BATS_TEST_TMPDIR/out-wd-multi.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_multi" \
    EVENT_NAME=workflow_dispatch \
    INPUT_FORMULAE="artagon/aitools/base artagon/aitools/foo"

  assert_output_eq "$out_multi" has_formulae "true"
  assert_output_eq "$out_multi" shard_count "2"
  assert_output_eq "$out_multi" use_merge "true"
  assert_output_eq "$out_multi" include_macos "false"
  assert_output_eq "$out_multi" matrix_oses_json '["ubuntu-24.04","ubuntu-24.04-arm"]'
  assert_output_eq "$out_multi" run_brew_style "true"
  local shards=""
  shards="$(get_output_value "$out_multi" shards_json)"
  jq -e '
    length == 2
    and ([.[].formulae] | sort == ["artagon/aitools/base","artagon/aitools/foo"])
  ' <<<"$shards" >/dev/null

  # Explicit INPUT_INCLUDE_MACOS=true enables macos-26 in matrix_oses_json.
  local out_wd_macos="$BATS_TEST_TMPDIR/out-wd-macos.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_wd_macos" \
    EVENT_NAME=workflow_dispatch \
    INPUT_FORMULAE="artagon/aitools/base" \
    INPUT_INCLUDE_MACOS="true"
  assert_output_eq "$out_wd_macos" include_macos "true"
  assert_output_eq "$out_wd_macos" matrix_oses_json '["macos-26","ubuntu-24.04","ubuntu-24.04-arm"]'

  # Invalid INPUT_INCLUDE_MACOS fails closed.
  local out_bad_macos="$BATS_TEST_TMPDIR/out-wd-bad-macos.txt"
  if run_plan_in_repo "$shell_bin" "$repo" "$out_bad_macos" \
    EVENT_NAME=workflow_dispatch INPUT_INCLUDE_MACOS="yes" 2>/dev/null; then
    printf 'Expected failure on invalid INPUT_INCLUDE_MACOS=yes\n' >&2
    return 1
  fi

  # Foreign tap, traversal, nonexistent formula, and shell metacharacters fail closed.
  local bad_token="" out_bad="$BATS_TEST_TMPDIR/out-wd-bad.txt"
  for bad_token in \
    "homebrew/core/jq" \
    "artagon/aitools/../foo" \
    "artagon/aitools/does-not-exist" \
    "artagon/aitools/foo;id"; do
    if run_plan_in_repo "$shell_bin" "$repo" "$out_bad" \
      EVENT_NAME=workflow_dispatch INPUT_FORMULAE="$bad_token" 2>/dev/null; then
      printf 'Expected workflow_dispatch rejection for INPUT_FORMULAE=[%s]\n' "$bad_token" >&2
      return 1
    fi
  done
}

case_push_to_main() {
  local shell_bin="$1"
  local repo="$BATS_TEST_TMPDIR/repo-push"
  init_test_repo "$repo"
  local before_sha=""
  before_sha="$(git -C "$repo" rev-parse HEAD)"

  # Formula + README bottle commit on main: full tap audit + README check, no macOS Bats, no test-bot.
  printf '# bottle block\n' >>"$repo/Formula/foo.rb"
  printf '\nTable refresh.\n' >>"$repo/README.md"
  git -C "$repo" add Formula/foo.rb README.md
  git -C "$repo" commit -q -m "foo: add bottles"

  local out_formula="$BATS_TEST_TMPDIR/out-push-formula.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_formula" \
    EVENT_NAME=push PUSH_BEFORE="$before_sha"

  assert_output_eq "$out_formula" has_formulae "false"
  assert_output_eq "$out_formula" shard_count "0"
  assert_output_eq "$out_formula" use_merge "false"
  assert_output_eq "$out_formula" include_macos "false"
  assert_output_eq "$out_formula" matrix_oses_json '["ubuntu-24.04","ubuntu-24.04-arm"]'
  assert_output_eq "$out_formula" run_brew_style "true"
  assert_output_eq "$out_formula" run_brew_readall "true"
  assert_output_eq "$out_formula" run_brew_audit_tap "true"
  assert_output_eq "$out_formula" run_ast_grep "true"
  assert_output_eq "$out_formula" run_bats_lint "true"
  assert_output_eq "$out_formula" run_provenance_bats "true"
  assert_output_eq "$out_formula" run_cask_bats "true"
  assert_output_eq "$out_formula" run_readme_check "true"
  assert_output_eq "$out_formula" run_tap_docs_check "true"
  assert_output_eq "$out_formula" run_lock_check "true"
  assert_output_eq "$out_formula" run_installer_bats_standalone "false"

  # Push modifying scripts/ runs full Linux lint/Bats with zero macOS runners (also test all-zero PUSH_BEFORE fallback).
  before_sha="$(git -C "$repo" rev-parse HEAD)"
  printf '# script edit\n' >>"$repo/scripts/ci/plan-ci.sh"
  git -C "$repo" add scripts/ci/plan-ci.sh
  git -C "$repo" commit -q -m "ci: update planner"

  local out_script="$BATS_TEST_TMPDIR/out-push-script.txt"
  run_plan_in_repo "$shell_bin" "$repo" "$out_script" \
    EVENT_NAME=push PUSH_BEFORE="0000000000000000000000000000000000000000"

  assert_output_eq "$out_script" has_formulae "false"
  assert_output_eq "$out_script" include_macos "false"
  assert_output_eq "$out_script" run_brew_audit_tap "true"
  assert_output_eq "$out_script" run_cask_bats "true"
  assert_output_eq "$out_script" run_readme_check "true"
}

write_fake_shard() {
  local shard_dir="$1"
  local formula="$2"
  local pkg_version="$3"
  local tag="$4"
  local matrix_os="$5"
  local head_sha="$6"
  local checkout_sha="$7"
  local run_id="$8"
  local run_attempt="$9"

  local bottles_dir="$shard_dir/bottles"
  local prov_dir="$shard_dir/provenance"
  mkdir -p "$bottles_dir" "$prov_dir"

  local brew_fn="${formula}--${pkg_version}.${tag}.bottle.tar.gz"
  local rel_fn="${formula}-${pkg_version}.${tag}.bottle.tar.gz"
  rel_fn="${rel_fn//@/%40}"
  rel_fn="${rel_fn//+/%2B}"
  local json_fn="${formula}--${pkg_version}.${tag}.bottle.json"
  local root_url="https://github.com/artagon/homebrew-aitools/releases/download/${formula}-${pkg_version}"

  printf 'fake-bottle-bytes-%s-%s-%s\n' "$formula" "$pkg_version" "$tag" >"$bottles_dir/$brew_fn"
  local bottle_sha=""
  bottle_sha="$(sha256_file "$bottles_dir/$brew_fn")"

  jq -n \
    --arg full "artagon/aitools/$formula" \
    --arg formula "$formula" \
    --arg pkg_version "$pkg_version" \
    --arg root_url "$root_url" \
    --arg tag "$tag" \
    --arg rel_fn "$rel_fn" \
    --arg brew_fn "$brew_fn" \
    --arg bottle_sha "$bottle_sha" \
    '{
      ($full): {
        formula: { name: $formula, pkg_version: $pkg_version },
        bottle: {
          root_url: $root_url,
          rebuild: 0,
          tags: {
            ($tag): {
              filename: $rel_fn,
              local_filename: $brew_fn,
              sha256: $bottle_sha
            }
          }
        }
      }
    }' >"$bottles_dir/$json_fn"
  local json_sha=""
  json_sha="$(sha256_file "$bottles_dir/$json_fn")"

  printf '{"spdxVersion":"SPDX-2.3","name":"%s"}\n' "$formula" >"$prov_dir/${rel_fn}.spdx.json"
  printf '{"bomFormat":"CycloneDX","specVersion":"1.6","metadata":{"component":{"name":"%s"}}}\n' "$formula" >"$prov_dir/${rel_fn}.cdx.json"
  local spdx_sha="" cdx_sha=""
  spdx_sha="$(sha256_file "$prov_dir/${rel_fn}.spdx.json")"
  cdx_sha="$(sha256_file "$prov_dir/${rel_fn}.cdx.json")"

  printf '%s  %s\n%s  %s\n' "$bottle_sha" "$brew_fn" "$bottle_sha" "$rel_fn" >"$prov_dir/SHA256SUMS"

  jq -n \
    --arg head_sha "$head_sha" \
    --arg checkout_sha "$checkout_sha" \
    --arg event_name "pull_request" \
    --arg ref "refs/pull/42/merge" \
    --arg run_id "$run_id" \
    --arg run_attempt "$run_attempt" \
    --arg matrix_os "$matrix_os" \
    --arg runner_os "macOS" \
    --arg runner_arch "ARM64" \
    --arg homebrew_version "Homebrew 4.6.0" \
    --arg formula "$formula" \
    --arg pkg_version "$pkg_version" \
    --arg root_url "$root_url" \
    --arg tag "$tag" \
    --arg brew_fn "$brew_fn" \
    --arg rel_fn "$rel_fn" \
    --arg bottle_sha "$bottle_sha" \
    --arg json_fn "$json_fn" \
    --arg json_sha "$json_sha" \
    --arg spdx_sha "$spdx_sha" \
    --arg cdx_sha "$cdx_sha" \
    '{
      schema: "artagon-bottle-build-manifest/v1",
      head_sha: $head_sha,
      checkout_sha: $checkout_sha,
      event_name: $event_name,
      ref: $ref,
      run_id: $run_id,
      run_attempt: $run_attempt,
      matrix_os: $matrix_os,
      runner_os: $runner_os,
      runner_arch: $runner_arch,
      homebrew_version: $homebrew_version,
      bottles: [{
        formula: $formula,
        pkg_version: $pkg_version,
        root_url: $root_url,
        rebuild: 0,
        tag: $tag,
        brew_filename: $brew_fn,
        release_filename: $rel_fn,
        bottle_sha256: $bottle_sha,
        bottle_json_filename: $json_fn,
        bottle_json_sha256: $json_sha,
        spdx_sha256: $spdx_sha,
        cdx_sha256: $cdx_sha
      }]
    }' >"$prov_dir/build-manifest.json"
}

case_merge_provenance_shards() {
  local shell_bin="$1"
  local head_sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  local checkout_sha="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local run_id="987654321"
  local run_attempt="2"
  local matrix_os="macos-26"
  local tag="arm64_tahoe"

  # Happy path: merge 2 shards (one with attempt=1, one with attempt=2, including + encoding).
  local shards_ok="$BATS_TEST_TMPDIR/shards-ok"
  local out_ok="$BATS_TEST_TMPDIR/merged-ok"
  write_fake_shard "$shards_ok/shard_${matrix_os}_shard-1" "beta+extra" "2.1.0" "$tag" "$matrix_os" "$head_sha" "$checkout_sha" "$run_id" "1"
  write_fake_shard "$shards_ok/shard_${matrix_os}_shard-2" "alpha" "1.0.0" "$tag" "$matrix_os" "$head_sha" "$checkout_sha" "$run_id" "2"

  env \
    SHARDS_DIR="$shards_ok" \
    OUT_DIR="$out_ok" \
    MATRIX_OS="$matrix_os" \
    HEAD_SHA="$head_sha" \
    RUN_ID="$run_id" \
    RUN_ATTEMPT="$run_attempt" \
    EXPECTED_SHARD_COUNT="2" \
    "$shell_bin" "$MERGE_SCRIPT"

  [[ -f "$out_ok/bottles/alpha--1.0.0.${tag}.bottle.tar.gz" ]]
  [[ -f "$out_ok/bottles/alpha--1.0.0.${tag}.bottle.json" ]]
  [[ -f "$out_ok/bottles/beta+extra--2.1.0.${tag}.bottle.tar.gz" ]]
  [[ -f "$out_ok/bottles/beta+extra--2.1.0.${tag}.bottle.json" ]]
  [[ -f "$out_ok/provenance/alpha-1.0.0.${tag}.bottle.tar.gz.spdx.json" ]]
  [[ -f "$out_ok/provenance/alpha-1.0.0.${tag}.bottle.tar.gz.cdx.json" ]]
  [[ -f "$out_ok/provenance/beta%2Bextra-2.1.0.${tag}.bottle.tar.gz.spdx.json" ]]
  [[ -f "$out_ok/provenance/beta%2Bextra-2.1.0.${tag}.bottle.tar.gz.cdx.json" ]]
  [[ -f "$out_ok/provenance/SHA256SUMS" ]]
  [[ -f "$out_ok/provenance/build-manifest.json" ]]

  jq -e \
    --arg head_sha "$head_sha" \
    --arg checkout_sha "$checkout_sha" \
    --arg run_id "$run_id" \
    --arg run_attempt "$run_attempt" \
    --arg matrix_os "$matrix_os" \
    '
      .schema == "artagon-bottle-build-manifest/v1"
      and .head_sha == $head_sha
      and .checkout_sha == $checkout_sha
      and .event_name == "pull_request"
      and .ref == "refs/pull/42/merge"
      and .run_id == $run_id
      and .run_attempt == $run_attempt
      and .matrix_os == $matrix_os
      and .runner_os == "macOS"
      and .runner_arch == "ARM64"
      and .homebrew_version == "Homebrew 4.6.0"
      and (.bottles | length == 2)
      and ([.bottles[].formula] == ["alpha","beta+extra"])
    ' "$out_ok/provenance/build-manifest.json" >/dev/null

  local sum_lines=""
  sum_lines="$(wc -l <"$out_ok/provenance/SHA256SUMS" | tr -d '[:space:]')"
  [[ "$sum_lines" -eq 4 ]]
  grep -Fq "alpha--1.0.0.${tag}.bottle.tar.gz" "$out_ok/provenance/SHA256SUMS"
  grep -Fq "alpha-1.0.0.${tag}.bottle.tar.gz" "$out_ok/provenance/SHA256SUMS"
  grep -Fq "beta%2Bextra-2.1.0.${tag}.bottle.tar.gz" "$out_ok/provenance/SHA256SUMS"

  # Reject duplicate bottle filename / (formula, tag) across shards.
  local shards_dup="$BATS_TEST_TMPDIR/shards-dup"
  write_fake_shard "$shards_dup/shard_${matrix_os}_shard-1" "alpha" "1.0.0" "$tag" "$matrix_os" "$head_sha" "$checkout_sha" "$run_id" "1"
  write_fake_shard "$shards_dup/shard_${matrix_os}_shard-2" "alpha" "1.0.0" "$tag" "$matrix_os" "$head_sha" "$checkout_sha" "$run_id" "1"
  if env SHARDS_DIR="$shards_dup" OUT_DIR="$BATS_TEST_TMPDIR/out-dup" MATRIX_OS="$matrix_os" \
    HEAD_SHA="$head_sha" RUN_ID="$run_id" RUN_ATTEMPT="$run_attempt" \
    "$shell_bin" "$MERGE_SCRIPT" 2>/dev/null; then
    printf 'Expected duplicate bottle rejection\n' >&2
    return 1
  fi

  # Reject tampered bottle tarball SHA-256.
  local shards_tamper="$BATS_TEST_TMPDIR/shards-tamper"
  write_fake_shard "$shards_tamper/shard_${matrix_os}_shard-1" "alpha" "1.0.0" "$tag" "$matrix_os" "$head_sha" "$checkout_sha" "$run_id" "1"
  printf 'tampered' >>"$shards_tamper/shard_${matrix_os}_shard-1/bottles/alpha--1.0.0.${tag}.bottle.tar.gz"
  if env SHARDS_DIR="$shards_tamper" OUT_DIR="$BATS_TEST_TMPDIR/out-tamper" MATRIX_OS="$matrix_os" \
    HEAD_SHA="$head_sha" RUN_ID="$run_id" RUN_ATTEMPT="$run_attempt" \
    "$shell_bin" "$MERGE_SCRIPT" 2>/dev/null; then
    printf 'Expected tampered bottle SHA-256 rejection\n' >&2
    return 1
  fi

  # Reject mismatched head_sha.
  local shards_bad_sha="$BATS_TEST_TMPDIR/shards-bad-sha"
  write_fake_shard "$shards_bad_sha/shard_${matrix_os}_shard-1" "alpha" "1.0.0" "$tag" "$matrix_os" "cccccccccccccccccccccccccccccccccccccccc" "$checkout_sha" "$run_id" "1"
  if env SHARDS_DIR="$shards_bad_sha" OUT_DIR="$BATS_TEST_TMPDIR/out-bad-sha" MATRIX_OS="$matrix_os" \
    HEAD_SHA="$head_sha" RUN_ID="$run_id" RUN_ATTEMPT="$run_attempt" \
    "$shell_bin" "$MERGE_SCRIPT" 2>/dev/null; then
    printf 'Expected mismatched head_sha rejection\n' >&2
    return 1
  fi

  # Reject mismatched matrix_os.
  local shards_bad_os="$BATS_TEST_TMPDIR/shards-bad-os"
  write_fake_shard "$shards_bad_os/shard_ubuntu-24.04_shard-1" "alpha" "1.0.0" "x86_64_linux" "ubuntu-24.04" "$head_sha" "$checkout_sha" "$run_id" "1"
  if env SHARDS_DIR="$shards_bad_os" OUT_DIR="$BATS_TEST_TMPDIR/out-bad-os" MATRIX_OS="$matrix_os" \
    HEAD_SHA="$head_sha" RUN_ID="$run_id" RUN_ATTEMPT="$run_attempt" \
    "$shell_bin" "$MERGE_SCRIPT" 2>/dev/null; then
    printf 'Expected mismatched matrix_os rejection\n' >&2
    return 1
  fi

  # Reject unreferenced stray file in shard bottles/.
  local shards_stray="$BATS_TEST_TMPDIR/shards-stray"
  write_fake_shard "$shards_stray/shard_${matrix_os}_shard-1" "alpha" "1.0.0" "$tag" "$matrix_os" "$head_sha" "$checkout_sha" "$run_id" "1"
  printf 'rogue' >"$shards_stray/shard_${matrix_os}_shard-1/bottles/rogue--1.0.0.${tag}.bottle.tar.gz"
  if env SHARDS_DIR="$shards_stray" OUT_DIR="$BATS_TEST_TMPDIR/out-stray" MATRIX_OS="$matrix_os" \
    HEAD_SHA="$head_sha" RUN_ID="$run_id" RUN_ATTEMPT="$run_attempt" \
    "$shell_bin" "$MERGE_SCRIPT" 2>/dev/null; then
    printf 'Expected unreferenced shard file rejection\n' >&2
    return 1
  fi
}

@test "bash 3.2: docs-only PR skips Homebrew setup and macOS Bats" {
  run case_docs_only_pr "$PLAN_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: single-formula PR uses single shard, validates Formula paths, and tracks deletes" {
  run case_single_formula_pr_and_validation "$PLAN_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: 7 independent formulae cap at 5 balanced shards with full coverage" {
  run case_multi_formula_capped_5_shards "$PLAN_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: intra-tap build deps group valhalla stack into one shard and track ripwire" {
  run case_intra_tap_dep_grouping "$PLAN_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: non-build intra-tap runtime dependency sets has_intra_tap_runtime_deps=true" {
  run case_runtime_dep_detection "$PLAN_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: workflow_dispatch shards explicit INPUT_FORMULAE, handles empty input, and rejects invalid tokens" {
  run case_workflow_dispatch "$PLAN_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: push to main runs full Linux audit and Bats suites with zero macOS runners" {
  run case_push_to_main "$PLAN_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: merge-provenance-shards merges flat artifacts and rejects duplicates, tampering, and mismatches" {
  run case_merge_provenance_shards "$PLAN_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 5+: docs-only PR skips Homebrew setup and macOS Bats" {
  run case_docs_only_pr "$PLAN_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: single-formula PR uses single shard, validates Formula paths, and tracks deletes" {
  run case_single_formula_pr_and_validation "$PLAN_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: 7 independent formulae cap at 5 balanced shards with full coverage" {
  run case_multi_formula_capped_5_shards "$PLAN_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: intra-tap build deps group valhalla stack into one shard and track ripwire" {
  run case_intra_tap_dep_grouping "$PLAN_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: non-build intra-tap runtime dependency sets has_intra_tap_runtime_deps=true" {
  run case_runtime_dep_detection "$PLAN_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: workflow_dispatch shards explicit INPUT_FORMULAE, handles empty input, and rejects invalid tokens" {
  run case_workflow_dispatch "$PLAN_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: push to main runs full Linux audit and Bats suites with zero macOS runners" {
  run case_push_to_main "$PLAN_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: merge-provenance-shards merges flat artifacts and rejects duplicates, tampering, and mismatches" {
  run case_merge_provenance_shards "$PLAN_MODERN_BASH"
  [ "$status" -eq 0 ]
}
