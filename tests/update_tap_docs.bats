#!/usr/bin/env bats
# Bats behavior and compatibility suite for scripts/update-tap-docs.sh and
# multi-marker README.md/ABOUT.md patch-policy enforcement (`artagon-shell/shell-testing/v1`).
#
# Executes every target contract explicitly under both stock macOS Bash 3.2
# (`BATS_BASH32`) and modern Bash 5+ (`BATS_MODERN_BASH`) in isolated
# `$BATS_TEST_TMPDIR` workspaces.

setup_file() {
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  export DOCS_BASH32="${BATS_BASH32:-/bin/bash}"
  export DOCS_MODERN_BASH="${BATS_MODERN_BASH:-$(command -v bash)}"
  export DOCS_REPO_ROOT="${BATS_REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)}"
  export DOCS_SCRIPT="$DOCS_REPO_ROOT/scripts/update-tap-docs.sh"
  export POLICY_SCRIPT="$DOCS_REPO_ROOT/scripts/ci/verify-patch-policy.sh"
  export PUBLISH_SCRIPT="$DOCS_REPO_ROOT/scripts/ci/publish-bottles.sh"
  export README_BOTTLES_SCRIPT="$DOCS_REPO_ROOT/scripts/update-readme-bottles.sh"
  export DOCS_HAS_BASH32=0

  [[ -x "$DOCS_SCRIPT" ]] || {
    printf 'Missing executable docs script: %s\n' "$DOCS_SCRIPT" >&2
    return 1
  }
  [[ -x "$DOCS_MODERN_BASH" ]] || {
    printf 'Missing Bash 5+ interpreter: %s\n' "$DOCS_MODERN_BASH" >&2
    return 1
  }

  local mod_ver=""
  mod_ver="$("$DOCS_MODERN_BASH" --version | awk 'NR == 1 { print; exit }')"
  [[ "$mod_ver" =~ version\ [5-9]\. ]] || {
    printf 'BATS_MODERN_BASH must identify Bash 5+ (got: %s)\n' "$mod_ver" >&2
    return 1
  }

  local b32_ver=""
  if [[ -x "$DOCS_BASH32" ]]; then
    b32_ver="$("$DOCS_BASH32" --version | awk 'NR == 1 { print; exit }')"
  fi
  if [[ "$b32_ver" =~ version\ 3\.2\. ]]; then
    DOCS_HAS_BASH32=1
  elif [[ "$(uname -s)" = "Darwin" ]]; then
    printf 'BATS_BASH32 must identify Bash 3.2 on Darwin (got: %s)\n' "${b32_ver:-missing}" >&2
    return 1
  fi
}

setup() {
  if [[ "$BATS_TEST_DESCRIPTION" == "bash 3.2:"* ]] && [[ "${DOCS_HAS_BASH32:-0}" -ne 1 ]]; then
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

case_live_repo_sync_and_coverage() {
  local shell_bin="$1"
  TAP_DOCS_REPO_ROOT="$DOCS_REPO_ROOT" "$shell_bin" "$DOCS_SCRIPT" --check

  local f="" name=""
  for f in "$DOCS_REPO_ROOT"/Formula/*.rb; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .rb)"
    grep -Fq "[\`${name}\`](Formula/${name}.rb)" "$DOCS_REPO_ROOT/README.md"
    grep -Fq "[\`${name}\`](Formula/${name}.rb)" "$DOCS_REPO_ROOT/ABOUT.md"
  done

  for f in "$DOCS_REPO_ROOT"/Casks/*.rb; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .rb)"
    grep -Fq "[\`${name}\`](Casks/${name}.rb)" "$DOCS_REPO_ROOT/README.md"
    grep -Fq "[\`${name}\`](Casks/${name}.rb)" "$DOCS_REPO_ROOT/ABOUT.md"
  done
}

case_fixture_rendering_edge_cases() {
  local shell_bin="$1"
  local repo="$BATS_TEST_TMPDIR/fixture-repo"
  mkdir -p "$repo/Formula" "$repo/Casks"
  local sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  cat >"$repo/Formula/alpha-bottled.rb" <<EOF
class AlphaBottled < Formula
  desc "Alpha tool | pipes escaped"
  homepage "https://github.com/example/alpha"
  url "https://github.com/example/alpha/archive/refs/tags/v1.2.3.tar.gz"
  sha256 "${sha}"
  license any_of: ["MIT", "Apache-2.0"]
  revision 2

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/alpha-bottled-1.2.3_2"
    sha256 x86_64_linux: "${sha}"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "${sha}"
    sha256 arm64_linux: "${sha}"
  end

  fails_with :gcc do
    version "13"
    cause "Need GCC 14+"
  end

  def install
    bin.install "alpha"
  end
end
EOF

  cat >"$repo/Formula/beta-source.rb" <<EOF
class BetaSource < Formula
  desc "Beta source-only tool"
  homepage "https://beta.example.org/"
  url "https://github.com/example/beta/archive/refs/tags/desk-v0.4.0.tar.gz"
  sha256 "${sha}"
  license :cannot_represent

  def install
    bin.install "beta"
  end
end
EOF

  cat >"$repo/Formula/gamma-scoped.rb" <<EOF
class GammaScoped < Formula
  desc "Gamma scoped tag tool"
  homepage "https://github.com/example/mono/tree/main/pkg"
  url "https://github.com/example/mono/archive/refs/tags/%40scope%2Fgamma%402.5.0.tar.gz"
  sha256 "${sha}"
  license all_of: ["BSD-3-Clause", "MIT"]

  def install
    bin.install "gamma"
  end
end
EOF

  cat >"$repo/Casks/sample-app.rb" <<'EOF'
cask "sample-app" do
  version "1.0.5"
  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  url "https://example.invalid/sample-#{version}.dmg"
  name "Sample App"
  desc "Native macOS sample app"
  homepage "https://sample.example.com/"

  livecheck do
    url :url
    strategy :github_latest
  end
end
EOF

  cat >"$repo/README.md" <<'EOF'
# Fixture Tap

<!-- BEGIN TAP_BADGES -->
stale
<!-- END TAP_BADGES -->

<!-- BEGIN TAP_INVENTORY -->
stale
<!-- END TAP_INVENTORY -->
EOF

  cat >"$repo/ABOUT.md" <<'EOF'
# About Fixture Tap

<!-- BEGIN ABOUT_INVENTORY -->
stale
<!-- END ABOUT_INVENTORY -->
EOF

  # Stale docs fail --check.
  local chk_rc=0
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT" --check >/dev/null 2>&1 || chk_rc=$?
  [[ "$chk_rc" -eq 1 ]]

  # Write updates both files atomically and makes --check pass.
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT"
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT" --check
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT" --check --readme-only
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT" --check --about-only

  # Verify badges, counts, canonical bottle tag order, pipe escaping, licenses, and singular cask.
  grep -Fq "formulae-3-8250df" "$repo/README.md"
  grep -Fq "casks-1-bf3989" "$repo/README.md"
  grep -Fq 'Total packaged tools: **4** (**3** formulae: **1** bottled, **2** source-only; **1** macOS cask).' "$repo/README.md"
  # shellcheck disable=SC2016
  grep -Fq '| [`alpha-bottled`](Formula/alpha-bottled.rb) | `1.2.3_2` | `MIT OR Apache-2.0` | `arm64_tahoe` · `arm64_linux` · `x86_64_linux` | [example/alpha](https://github.com/example/alpha) — Alpha tool \| pipes escaped |' "$repo/README.md"
  # shellcheck disable=SC2016
  grep -Fq '| [`beta-source`](Formula/beta-source.rb) | `0.4.0` | Custom (`LICENSE`) | source | [beta.example.org](https://beta.example.org/) — Beta source-only tool |' "$repo/README.md"
  # shellcheck disable=SC2016
  grep -Fq '| [`gamma-scoped`](Formula/gamma-scoped.rb) | `2.5.0` | `BSD-3-Clause AND MIT` | source | [github.com/example/mono/tree/main/pkg](https://github.com/example/mono/tree/main/pkg) — Gamma scoped tag tool |' "$repo/README.md"
  # shellcheck disable=SC2016
  grep -Fq '| [`sample-app`](Casks/sample-app.rb) | `1.0.5` | [sample.example.com](https://sample.example.com/) — Native macOS sample app |' "$repo/README.md"
  # shellcheck disable=SC2016
  grep -Fq '| [`sample-app`](Casks/sample-app.rb) | Cask | `1.0.5` | — | macOS cask | [sample.example.com](https://sample.example.com/) — Native macOS sample app |' "$repo/ABOUT.md"

  # Adding a second cask pluralizes to "casks"; removing Casks/ renders 0 casks cleanly.
  cp "$repo/Casks/sample-app.rb" "$repo/Casks/second-app.rb"
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT"
  grep -Fq "2** macOS casks)." "$repo/README.md"
  grep -Fq "2** macOS casks." "$repo/ABOUT.md"

  rm -rf "$repo/Casks"
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT"
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT" --check
  grep -Fq "casks-0-bf3989" "$repo/README.md"
  ! grep -Fq "### macOS Casks" "$repo/README.md"

  # Missing markers fail closed.
  printf '# Broken ABOUT\n' >"$repo/ABOUT.md"
  local bad_rc=0
  TAP_DOCS_REPO_ROOT="$repo" "$shell_bin" "$DOCS_SCRIPT" --check >/dev/null 2>&1 || bad_rc=$?
  [[ "$bad_rc" -eq 1 ]]
}

case_publish_patch_policy_readme_and_about() {
  local shell_bin="$1"
  local git_repo="$BATS_TEST_TMPDIR/publish-docs-repo"
  local rtemp="$BATS_TEST_TMPDIR/rtemp"
  mkdir -p "$git_repo/Formula" "$rtemp/publish-stage"
  local sha="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

  export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"
  git -C "$git_repo" init -q -b main

  cat >"$git_repo/Formula/demo.rb" <<EOF
class Demo < Formula
  desc "Demo tool"
  homepage "https://github.com/example/demo"
  url "https://github.com/example/demo/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "${sha}"
  license "MIT"

  def install
    bin.install "demo"
  end
end
EOF

  cat >"$git_repo/README.md" <<'EOF'
# Demo Tap

<!-- BEGIN TAP_BADGES -->
<!-- END TAP_BADGES -->

<!-- BEGIN TAP_INVENTORY -->
<!-- END TAP_INVENTORY -->

<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->
<!-- END BOTTLE_PROVENANCE_TABLE -->
EOF

  cat >"$git_repo/ABOUT.md" <<'EOF'
# About Demo Tap

<!-- BEGIN ABOUT_INVENTORY -->
<!-- END ABOUT_INVENTORY -->
EOF

  TAP_DOCS_REPO_ROOT="$git_repo" "$shell_bin" "$DOCS_SCRIPT"
  PROVENANCE_REPO_ROOT="$git_repo" README_BOTTLES_FILE="$git_repo/README.md" \
    "$shell_bin" "$README_BOTTLES_SCRIPT"
  git -C "$git_repo" add .
  git -C "$git_repo" commit -q -m "base"
  local base_sha=""
  base_sha="$(git -C "$git_repo" rev-parse HEAD)"

  # PR branch bumps demo to 1.1.0 without touching README.md or ABOUT.md.
  git -C "$git_repo" checkout -q -b pr
  awk '{ sub(/v1\.0\.0\.tar\.gz/, "v1.1.0.tar.gz"); print }' "$git_repo/Formula/demo.rb" >"$git_repo/Formula/demo.rb.tmp"
  mv "$git_repo/Formula/demo.rb.tmp" "$git_repo/Formula/demo.rb"
  git -C "$git_repo" commit -q -am "demo 1.1.0"
  local head_sha=""
  head_sha="$(git -C "$git_repo" rev-parse HEAD)"

  # Simulated publish stage adds bottle block and refreshes README.md + ABOUT.md.
  cat >"$git_repo/Formula/demo.rb" <<EOF
class Demo < Formula
  desc "Demo tool"
  homepage "https://github.com/example/demo"
  url "https://github.com/example/demo/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "${sha}"
  license "MIT"

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/demo-1.1.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "${sha}"
  end

  def install
    bin.install "demo"
  end
end
EOF
  PROVENANCE_REPO_ROOT="$git_repo" README_BOTTLES_FILE="$git_repo/README.md" \
    "$shell_bin" "$README_BOTTLES_SCRIPT"
  TAP_DOCS_REPO_ROOT="$git_repo" "$shell_bin" "$DOCS_SCRIPT"
  git -C "$git_repo" add Formula/demo.rb README.md ABOUT.md
  git -C "$git_repo" commit -q -m "demo: add bottle and refresh docs"

  git -C "$git_repo" format-patch --stdout "$base_sha..HEAD" >"$rtemp/publish-stage/commits.mbox"
  git -C "$git_repo" checkout -q main

  jq -cn --arg sha "$sha" '{
    schema: "artagon-bottle-release-map/v1",
    bottles: [{
      formula: "demo",
      pkg_version: "1.1.0",
      release_tag: "demo-1.1.0",
      root_url: "https://github.com/artagon/homebrew-aitools/releases/download/demo-1.1.0",
      rebuild: 0,
      tag: "arm64_tahoe",
      brew_filename: "demo--1.1.0.arm64_tahoe.bottle.tar.gz",
      release_filename: "demo-1.1.0.arm64_tahoe.bottle.tar.gz",
      bottle_sha256: $sha
    }]
  }' >"$rtemp/publish-stage/release-map.json"
  local map_sha="" mbox_sha=""
  map_sha="$(sha256_file "$rtemp/publish-stage/release-map.json")"
  mbox_sha="$(sha256_file "$rtemp/publish-stage/commits.mbox")"

  (
    cd "$git_repo" &&
      GITHUB_REF="refs/heads/main" \
        RUNNER_TEMP="$rtemp" \
        BASE_MAIN_SHA="$base_sha" \
        HEAD_SHA="$head_sha" \
        COMMITS_MBOX_SHA256="$mbox_sha" \
        RELEASE_MAP_SHA256="$map_sha" \
        SKIP_FETCH_HEAD_SHA="1" \
        "$shell_bin" "$PUBLISH_SCRIPT" verify-patch-policy
  )

  # Tampering ABOUT.md outside ABOUT_INVENTORY must be rejected.
  git -C "$git_repo" reset -q --hard "$base_sha"
  git -C "$git_repo" checkout -q pr
  printf '\nUnauthorized edit outside markers.\n' >>"$git_repo/ABOUT.md"
  git -C "$git_repo" add ABOUT.md
  git -C "$git_repo" commit -q -m "tamper about"
  git -C "$git_repo" format-patch --stdout "$base_sha..HEAD" >"$rtemp/publish-stage/commits.mbox"
  mbox_sha="$(sha256_file "$rtemp/publish-stage/commits.mbox")"
  git -C "$git_repo" checkout -q main

  local bad_about_rc=0
  (
    cd "$git_repo" &&
      GITHUB_REF="refs/heads/main" \
        RUNNER_TEMP="$rtemp" \
        BASE_MAIN_SHA="$base_sha" \
        HEAD_SHA="$head_sha" \
        COMMITS_MBOX_SHA256="$mbox_sha" \
        RELEASE_MAP_SHA256="$map_sha" \
        SKIP_FETCH_HEAD_SHA="1" \
        "$shell_bin" "$PUBLISH_SCRIPT" verify-patch-policy
  ) >"$BATS_TEST_TMPDIR/bad-about.out" 2>"$BATS_TEST_TMPDIR/bad-about.err" || bad_about_rc=$?
  [[ "$bad_about_rc" -eq 1 ]]
  grep -Fq "ABOUT.md modified outside ABOUT_INVENTORY markers" "$BATS_TEST_TMPDIR/bad-about.err"
}

@test "bash 3.2: live README.md and ABOUT.md match Formula/*.rb and Casks/*.rb" {
  run case_live_repo_sync_and_coverage "$DOCS_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: render badges, inventories, licenses, bottle order, and cask counts" {
  run case_fixture_rendering_edge_cases "$DOCS_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: publish-bottles verify-patch-policy allows fenced README/ABOUT refresh and rejects tampering" {
  run case_publish_patch_policy_readme_and_about "$DOCS_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 5+: live README.md and ABOUT.md match Formula/*.rb and Casks/*.rb" {
  run case_live_repo_sync_and_coverage "$DOCS_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: render badges, inventories, licenses, bottle order, and cask counts" {
  run case_fixture_rendering_edge_cases "$DOCS_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: publish-bottles verify-patch-policy allows fenced README/ABOUT refresh and rejects tampering" {
  run case_publish_patch_policy_readme_and_about "$DOCS_MODERN_BASH"
  [ "$status" -eq 0 ]
}
