#!/usr/bin/env bats
# Bats behavior and compatibility suite for scripts/check-aitools-lock.sh and
# scripts/autobump.sh lockfile co-bumping (`artagon-shell/shell-testing/v1`).

setup_file() {
  export LOCK_BASH32="${BATS_BASH32:-/bin/bash}"
  export LOCK_MODERN_BASH="${BATS_MODERN_BASH:-$(command -v bash)}"
  export LOCK_REPO_ROOT="${BATS_REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)}"
  export LOCK_SCRIPT="$LOCK_REPO_ROOT/scripts/check-aitools-lock.sh"
  export AUTOBUMP_SCRIPT="$LOCK_REPO_ROOT/scripts/autobump.sh"
  export LOCK_HAS_BASH32=0

  [[ -x "$LOCK_SCRIPT" ]] || {
    printf 'Missing executable lock verifier: %s\n' "$LOCK_SCRIPT" >&2
    return 1
  }
  [[ -x "$AUTOBUMP_SCRIPT" ]] || {
    printf 'Missing executable autobump script: %s\n' "$AUTOBUMP_SCRIPT" >&2
    return 1
  }

  local mod_ver=""
  mod_ver="$("$LOCK_MODERN_BASH" --version | awk 'NR == 1 { print; exit }')"
  [[ "$mod_ver" =~ version\ [5-9]\. ]] || {
    printf 'BATS_MODERN_BASH must identify Bash 5+ (got: %s)\n' "$mod_ver" >&2
    return 1
  }

  local b32_ver=""
  if [[ -x "$LOCK_BASH32" ]]; then
    b32_ver="$("$LOCK_BASH32" --version | awk 'NR == 1 { print; exit }')"
  fi
  if [[ "$b32_ver" =~ version\ 3\.2\. ]]; then
    LOCK_HAS_BASH32=1
  elif [[ "$(uname -s)" = "Darwin" ]]; then
    printf 'BATS_BASH32 must identify Bash 3.2 on Darwin (got: %s)\n' "${b32_ver:-missing}" >&2
    return 1
  fi
}

setup() {
  if [[ "$BATS_TEST_DESCRIPTION" == "bash 3.2:"* ]] && [[ "${LOCK_HAS_BASH32:-0}" -ne 1 ]]; then
    skip "macOS Bash 3.2 interpreter is not installed on $(uname -s)"
  fi
  export HOME="$BATS_TEST_TMPDIR/home"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$HOME" "$TMPDIR"
}

create_lock_fixture() {
  local dir="$1"
  local acli_mode="$2" # staged | present
  rm -rf -- "$dir"
  mkdir -p "$dir/Formula" "$dir/versions"

  cat >"$dir/Formula/agent-mail.rb" <<'EOF'
class AgentMail < Formula
  desc "Agent Mail"
  homepage "https://example.invalid/agent-mail"
  license :cannot_represent

  on_macos do
    on_arm do
      url "https://example.invalid/agent-mail-0.3.41-darwin-arm64.tar.xz"
      sha256 "1111111111111111111111111111111111111111111111111111111111111111"
    end
    on_intel do
      url "https://example.invalid/agent-mail-0.3.41-darwin-x86_64.tar.xz"
      sha256 "2222222222222222222222222222222222222222222222222222222222222222"
    end
  end

  on_linux do
    on_arm do
      url "https://example.invalid/agent-mail-0.3.41-linux-arm64.tar.xz"
      sha256 "3333333333333333333333333333333333333333333333333333333333333333"
    end
    on_intel do
      url "https://example.invalid/agent-mail-0.3.41-linux-x86_64.tar.xz"
      sha256 "4444444444444444444444444444444444444444444444444444444444444444"
    end
  end
end
EOF

  cat >"$dir/Formula/nats.rb" <<'EOF'
class Nats < Formula
  desc "NATS CLI"
  homepage "https://example.invalid/nats"
  url "https://example.invalid/nats-0.5.2.tar.gz"
  sha256 "5555555555555555555555555555555555555555555555555555555555555555"
  license "Apache-2.0"
end
EOF

  cat >"$dir/Formula/nats-server.rb" <<'EOF'
class NatsServer < Formula
  desc "NATS server"
  homepage "https://example.invalid/nats-server"
  url "https://example.invalid/nats-server-2.15.3.tar.gz"
  sha256 "6666666666666666666666666666666666666666666666666666666666666666"
  license "Apache-2.0"
end
EOF

  cat >"$dir/Formula/br.rb" <<'EOF'
class Br < Formula
  desc "Beads Rust"
  homepage "https://example.invalid/br"
  license :cannot_represent

  on_macos do
    on_arm do
      url "https://example.invalid/br-0.7.6-darwin-arm64.tar.gz"
      sha256 "aaaa111111111111111111111111111111111111111111111111111111111111"
    end
    on_intel do
      url "https://example.invalid/br-0.7.6-darwin-x86_64.tar.gz"
      sha256 "aaaa222222222222222222222222222222222222222222222222222222222222"
    end
  end

  on_linux do
    on_arm do
      url "https://example.invalid/br-0.7.6-linux-arm64.tar.gz"
      sha256 "aaaa333333333333333333333333333333333333333333333333333333333333"
    end
    on_intel do
      url "https://example.invalid/br-0.7.6-linux-x86_64.tar.gz"
      sha256 "aaaa444444444444444444444444444444444444444444444444444444444444"
    end
  end
end
EOF

  cat >"$dir/Formula/bd.rb" <<'EOF'
class Bd < Formula
  desc "Beads"
  homepage "https://example.invalid/bd"
  license "MIT"

  on_macos do
    on_arm do
      url "https://example.invalid/bd-1.3.4-darwin-arm64.tar.gz"
      sha256 "bbbb111111111111111111111111111111111111111111111111111111111111"
    end
    on_intel do
      url "https://example.invalid/bd-1.3.4-darwin-x86_64.tar.gz"
      sha256 "bbbb222222222222222222222222222222222222222222222222222222222222"
    end
  end

  on_linux do
    on_arm do
      url "https://example.invalid/bd-1.3.4-linux-arm64.tar.gz"
      sha256 "bbbb333333333333333333333333333333333333333333333333333333333333"
    end
    on_intel do
      url "https://example.invalid/bd-1.3.4-linux-x86_64.tar.gz"
      sha256 "bbbb444444444444444444444444444444444444444444444444444444444444"
    end
  end
end
EOF

  if [[ "$acli_mode" = "present" ]]; then
    cat >"$dir/Formula/acli.rb" <<'EOF'
class Acli < Formula
  desc "acli"
  homepage "https://example.invalid/acli"
  url "https://example.invalid/acli-0.1.0.tar.gz"
  sha256 "cccc111111111111111111111111111111111111111111111111111111111111"
  license "Apache-2.0"

  resource "guest-aarch64-linux-musl" do
    url "https://example.invalid/acli-guest-0.1.0-aarch64-unknown-linux-musl.tar.xz"
    sha256 "cccc222222222222222222222222222222222222222222222222222222222222"
  end

  resource "guest-x86_64-linux-musl" do
    url "https://example.invalid/acli-guest-0.1.0-x86_64-unknown-linux-musl.tar.xz"
    sha256 "cccc333333333333333333333333333333333333333333333333333333333333"
  end
end
EOF
  fi

  local nix_status="staged"
  local flake_rev="null"
  local vendor_hash="null"
  local drv_id="null"
  if [[ "$acli_mode" = "present" ]]; then
    nix_status="present"
    flake_rev='"0123456789abcdef0123456789abcdef01234567"'
    vendor_hash='"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="'
    drv_id='"acli-vm-0.1.0.drv"'
  fi

  cat >"$dir/versions/aitools-lock.json" <<EOF
{
  "schema": "artagon-aitools-lock/v1",
  "artifacts": [
    {"package": "agent-mail", "version": "0.3.41", "artifact_role": "binary", "platform": "darwin-arm64", "status": "present", "formula": "Formula/agent-mail.rb", "url": "https://example.invalid/agent-mail-0.3.41-darwin-arm64.tar.xz", "sha256": "1111111111111111111111111111111111111111111111111111111111111111"},
    {"package": "agent-mail", "version": "0.3.41", "artifact_role": "binary", "platform": "darwin-x86_64", "status": "present", "formula": "Formula/agent-mail.rb", "url": "https://example.invalid/agent-mail-0.3.41-darwin-x86_64.tar.xz", "sha256": "2222222222222222222222222222222222222222222222222222222222222222"},
    {"package": "agent-mail", "version": "0.3.41", "artifact_role": "binary", "platform": "linux-arm64", "status": "present", "formula": "Formula/agent-mail.rb", "url": "https://example.invalid/agent-mail-0.3.41-linux-arm64.tar.xz", "sha256": "3333333333333333333333333333333333333333333333333333333333333333"},
    {"package": "agent-mail", "version": "0.3.41", "artifact_role": "binary", "platform": "linux-x86_64", "status": "present", "formula": "Formula/agent-mail.rb", "url": "https://example.invalid/agent-mail-0.3.41-linux-x86_64.tar.xz", "sha256": "4444444444444444444444444444444444444444444444444444444444444444"},
    {"package": "nats", "version": "0.5.2", "artifact_role": "source", "platform": "all", "status": "present", "formula": "Formula/nats.rb", "url": "https://example.invalid/nats-0.5.2.tar.gz", "sha256": "5555555555555555555555555555555555555555555555555555555555555555"},
    {"package": "nats-server", "version": "2.15.3", "artifact_role": "source", "platform": "all", "status": "present", "formula": "Formula/nats-server.rb", "url": "https://example.invalid/nats-server-2.15.3.tar.gz", "sha256": "6666666666666666666666666666666666666666666666666666666666666666"},
    {"package": "br", "version": "0.7.6", "artifact_role": "binary", "platform": "darwin-arm64", "status": "present", "formula": "Formula/br.rb", "url": "https://example.invalid/br-0.7.6-darwin-arm64.tar.gz", "sha256": "aaaa111111111111111111111111111111111111111111111111111111111111"},
    {"package": "br", "version": "0.7.6", "artifact_role": "binary", "platform": "darwin-x86_64", "status": "present", "formula": "Formula/br.rb", "url": "https://example.invalid/br-0.7.6-darwin-x86_64.tar.gz", "sha256": "aaaa222222222222222222222222222222222222222222222222222222222222"},
    {"package": "br", "version": "0.7.6", "artifact_role": "binary", "platform": "linux-arm64", "status": "present", "formula": "Formula/br.rb", "url": "https://example.invalid/br-0.7.6-linux-arm64.tar.gz", "sha256": "aaaa333333333333333333333333333333333333333333333333333333333333"},
    {"package": "br", "version": "0.7.6", "artifact_role": "binary", "platform": "linux-x86_64", "status": "present", "formula": "Formula/br.rb", "url": "https://example.invalid/br-0.7.6-linux-x86_64.tar.gz", "sha256": "aaaa444444444444444444444444444444444444444444444444444444444444"},
    {"package": "bd", "version": "1.3.4", "artifact_role": "binary", "platform": "darwin-arm64", "status": "present", "formula": "Formula/bd.rb", "url": "https://example.invalid/bd-1.3.4-darwin-arm64.tar.gz", "sha256": "bbbb111111111111111111111111111111111111111111111111111111111111"},
    {"package": "bd", "version": "1.3.4", "artifact_role": "binary", "platform": "darwin-x86_64", "status": "present", "formula": "Formula/bd.rb", "url": "https://example.invalid/bd-1.3.4-darwin-x86_64.tar.gz", "sha256": "bbbb222222222222222222222222222222222222222222222222222222222222"},
    {"package": "bd", "version": "1.3.4", "artifact_role": "binary", "platform": "linux-arm64", "status": "present", "formula": "Formula/bd.rb", "url": "https://example.invalid/bd-1.3.4-linux-arm64.tar.gz", "sha256": "bbbb333333333333333333333333333333333333333333333333333333333333"},
    {"package": "bd", "version": "1.3.4", "artifact_role": "binary", "platform": "linux-x86_64", "status": "present", "formula": "Formula/bd.rb", "url": "https://example.invalid/bd-1.3.4-linux-x86_64.tar.gz", "sha256": "bbbb444444444444444444444444444444444444444444444444444444444444"},
    {"package": "acli", "version": "0.1.0", "artifact_role": "source", "platform": "all", "status": "${acli_mode}", "formula": "Formula/acli.rb", "url": "https://example.invalid/acli-0.1.0.tar.gz", "sha256": "cccc111111111111111111111111111111111111111111111111111111111111"},
    {"package": "acli", "version": "0.1.0", "artifact_role": "guest-musl", "platform": "linux-arm64", "resource": "guest-aarch64-linux-musl", "status": "${acli_mode}", "formula": "Formula/acli.rb", "url": "https://example.invalid/acli-guest-0.1.0-aarch64-unknown-linux-musl.tar.xz", "sha256": "cccc222222222222222222222222222222222222222222222222222222222222"},
    {"package": "acli", "version": "0.1.0", "artifact_role": "guest-musl", "platform": "linux-x86_64", "resource": "guest-x86_64-linux-musl", "status": "${acli_mode}", "formula": "Formula/acli.rb", "url": "https://example.invalid/acli-guest-0.1.0-x86_64-unknown-linux-musl.tar.xz", "sha256": "cccc333333333333333333333333333333333333333333333333333333333333"}
  ],
  "nix_closure": {
    "status": "${nix_status}",
    "flake_lock_rev": ${flake_rev},
    "vendor_hash": ${vendor_hash},
    "guest_drv_identity": ${drv_id},
    "excluded_from_guest_erofs": ["bd", "br"]
  }
}
EOF
}

case_lock_verification_and_perturbations() {
  local shell_bin="$1"
  local fx="$BATS_TEST_TMPDIR/fx-staged"
  create_lock_fixture "$fx" staged

  # 1. Valid staged acli lockfile passes (including --json output).
  local json_out=""
  json_out="$("$shell_bin" "$LOCK_SCRIPT" --lockfile "$fx/versions/aitools-lock.json" --formula-dir "$fx/Formula" --json)"
  jq -e '.ok == true and .checked == 17 and .failed == 0' <<<"$json_out" >/dev/null

  # 2. One-platform br hash perturbation fails closed with exact single-platform diagnostics (no IFS column shift).
  local br_drift="$BATS_TEST_TMPDIR/br-drift.json"
  jq '(.artifacts[] | select(.package == "br" and .platform == "linux-arm64") | .sha256) = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' \
    "$fx/versions/aitools-lock.json" >"$br_drift"
  local br_drift_json="" br_drift_rc=0
  br_drift_json="$("$shell_bin" "$LOCK_SCRIPT" --lockfile "$br_drift" --formula-dir "$fx/Formula" --json)" || br_drift_rc=$?
  [[ "$br_drift_rc" -ne 0 ]]
  jq -e '
    .ok == false
    and .failed == 2
    and (.errors | all(contains("linux-arm64")))
    and (.errors | any(contains("resource=https://")) | not)
  ' <<<"$br_drift_json" >/dev/null

  # 3. One-platform bd URL perturbation fails closed.
  local bd_drift="$BATS_TEST_TMPDIR/bd-drift.json"
  jq '(.artifacts[] | select(.package == "bd" and .platform == "linux-x86_64") | .url) = "https://example.invalid/bd-tampered.tar.gz"' \
    "$fx/versions/aitools-lock.json" >"$bd_drift"
  if "$shell_bin" "$LOCK_SCRIPT" --lockfile "$bd_drift" --formula-dir "$fx/Formula" 2>/dev/null; then
    printf 'Expected failure on bd linux-x86_64 URL perturbation\n' >&2
    return 1
  fi

  # 4. Missing formula for a present package fails closed.
  rm -f "$fx/Formula/nats-server.rb"
  if "$shell_bin" "$LOCK_SCRIPT" --lockfile "$fx/versions/aitools-lock.json" --formula-dir "$fx/Formula" 2>/dev/null; then
    printf 'Expected failure when present formula is missing\n' >&2
    return 1
  fi

  # 5. Present acli with guest musl resources + valid Cargo.lock passes; guest resource perturbation & statsig crate fail.
  local fx_full="$BATS_TEST_TMPDIR/fx-full"
  create_lock_fixture "$fx_full" present

  cat >"$fx_full/Cargo.lock" <<'EOF'
version = 4

[[package]]
name = "statig"
version = "0.4.1"
EOF
  "$shell_bin" "$LOCK_SCRIPT" \
    --lockfile "$fx_full/versions/aitools-lock.json" \
    --formula-dir "$fx_full/Formula" \
    --cargo-lock "$fx_full/Cargo.lock" >/dev/null

  # Guest musl resource hash drift must fail.
  local guest_drift="$BATS_TEST_TMPDIR/guest-drift.json"
  jq '(.artifacts[] | select(.package == "acli" and .resource == "guest-x86_64-linux-musl") | .sha256) = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"' \
    "$fx_full/versions/aitools-lock.json" >"$guest_drift"
  if "$shell_bin" "$LOCK_SCRIPT" --lockfile "$guest_drift" --formula-dir "$fx_full/Formula" --cargo-lock "$fx_full/Cargo.lock" 2>/dev/null; then
    printf 'Expected failure on acli guest-musl resource hash perturbation\n' >&2
    return 1
  fi

  # Commercial statsig crate in Cargo.lock must fail.
  cat >"$fx_full/Cargo.bad.lock" <<'EOF'
version = 4

[[package]]
name = "statig"
version = "0.4.1"

[[package]]
name = "statsig-rust"
version = "1.0.0"
EOF
  if "$shell_bin" "$LOCK_SCRIPT" \
    --lockfile "$fx_full/versions/aitools-lock.json" \
    --formula-dir "$fx_full/Formula" \
    --cargo-lock "$fx_full/Cargo.bad.lock" 2>/dev/null; then
    printf 'Expected failure when Cargo.lock includes commercial statsig crate\n' >&2
    return 1
  fi

  # Wrong statig version in Cargo.lock must fail.
  cat >"$fx_full/Cargo.old-statig.lock" <<'EOF'
version = 4

[[package]]
name = "statig"
version = "0.3.0"
EOF
  if "$shell_bin" "$LOCK_SCRIPT" \
    --lockfile "$fx_full/versions/aitools-lock.json" \
    --formula-dir "$fx_full/Formula" \
    --cargo-lock "$fx_full/Cargo.old-statig.lock" 2>/dev/null; then
    printf 'Expected failure when Cargo.lock pins wrong statig version\n' >&2
    return 1
  fi

  # 6. Dual statig versions (0.4.1 + 0.3.0) in Cargo.lock must fail.
  cat >"$fx_full/Cargo.dual-statig.lock" <<'EOF'
version = 4

[[package]]
name = "statig"
version = "0.4.1"

[[package]]
name = "statig"
version = "0.3.0"
EOF
  if "$shell_bin" "$LOCK_SCRIPT" \
    --lockfile "$fx_full/versions/aitools-lock.json" \
    --formula-dir "$fx_full/Formula" \
    --cargo-lock "$fx_full/Cargo.dual-statig.lock" 2>/dev/null; then
    printf 'Expected failure when Cargo.lock includes dual statig versions\n' >&2
    return 1
  fi

  # 7. Case-insensitive Statsig crate with CRLF endings must fail.
  printf 'version = 4\r\n\r\n[[package]]\r\nname = "statig"\r\nversion = "0.4.1"\r\n\r\n[[package]]\r\nname = "Statsig-SDK"\r\nversion = "1.0.0"\r\n' >"$fx_full/Cargo.crlf.lock"
  if "$shell_bin" "$LOCK_SCRIPT" \
    --lockfile "$fx_full/versions/aitools-lock.json" \
    --formula-dir "$fx_full/Formula" \
    --cargo-lock "$fx_full/Cargo.crlf.lock" 2>/dev/null; then
    printf 'Expected failure on uppercase Statsig crate with CRLF endings\n' >&2
    return 1
  fi

  # 8. Version drift (9.9.9 and dotted-prefix 0.7 against 0.7.6 URLs) must fail.
  local ver_drift="$BATS_TEST_TMPDIR/ver-drift.json"
  jq '(.artifacts[] | select(.package == "br") | .version) = "9.9.9"' \
    "$fx_full/versions/aitools-lock.json" >"$ver_drift"
  if "$shell_bin" "$LOCK_SCRIPT" --lockfile "$ver_drift" --formula-dir "$fx_full/Formula" 2>/dev/null; then
    printf 'Expected failure on br version drift (9.9.9 vs 0.7.6 URLs)\n' >&2
    return 1
  fi

  local prefix_drift="$BATS_TEST_TMPDIR/prefix-drift.json"
  jq '(.artifacts[] | select(.package == "br") | .version) = "0.7"' \
    "$fx_full/versions/aitools-lock.json" >"$prefix_drift"
  if "$shell_bin" "$LOCK_SCRIPT" --lockfile "$prefix_drift" --formula-dir "$fx_full/Formula" 2>/dev/null; then
    printf 'Expected failure on dotted-prefix version drift (0.7 vs 0.7.6 URLs)\n' >&2
    return 1
  fi

  # 9. Present acli with staged nix_closure must fail.
  local nix_staged="$BATS_TEST_TMPDIR/nix-staged.json"
  jq '.nix_closure.status = "staged"' "$fx_full/versions/aitools-lock.json" >"$nix_staged"
  if "$shell_bin" "$LOCK_SCRIPT" --lockfile "$nix_staged" --formula-dir "$fx_full/Formula" 2>/dev/null; then
    printf 'Expected failure when acli is present but nix_closure is staged\n' >&2
    return 1
  fi

  # 10. Unsafe acli_cargo_lock path traversal must fail.
  local bad_cargo_path="$BATS_TEST_TMPDIR/bad-cargo-path.json"
  jq '.nix_closure.acli_cargo_lock = "../outside/Cargo.lock"' "$fx_full/versions/aitools-lock.json" >"$bad_cargo_path"
  if "$shell_bin" "$LOCK_SCRIPT" --lockfile "$bad_cargo_path" --formula-dir "$fx_full/Formula" 2>/dev/null; then
    printf 'Expected failure on acli_cargo_lock path traversal\n' >&2
    return 1
  fi

  # 11. Malformed non-string JSON fields emit valid --json failure output instead of crashing jq.
  local malformed="$BATS_TEST_TMPDIR/malformed.json"
  cat >"$malformed" <<'EOF'
{"schema": 123, "artifacts": [42, {"package": "../evil", "version": 99}], "nix_closure": {"status": 7}}
EOF
  local bad_json_out="" bad_json_rc=0
  bad_json_out="$("$shell_bin" "$LOCK_SCRIPT" --lockfile "$malformed" --formula-dir "$fx_full/Formula" --json)" || bad_json_rc=$?
  [[ "$bad_json_rc" -ne 0 ]]
  jq -e '.ok == false and .failed > 0 and (.errors | length) > 0' <<<"$bad_json_out" >/dev/null
}

case_autobump_sync_lock() {
  local shell_bin="$1"
  local fx="$BATS_TEST_TMPDIR/fx-bump"
  create_lock_fixture "$fx" present

  # Simulate bumping br (all 4 platforms), bd (all 4 platforms), and acli (source + both guest musl resources).
  cat >"$fx/Formula/br.rb" <<'EOF'
class Br < Formula
  desc "Beads Rust"
  homepage "https://example.invalid/br"
  license :cannot_represent

  on_macos do
    on_arm do
      url "https://example.invalid/br-0.7.7-darwin-arm64.tar.gz"
      sha256 "dddd111111111111111111111111111111111111111111111111111111111111"
    end
    on_intel do
      url "https://example.invalid/br-0.7.7-darwin-x86_64.tar.gz"
      sha256 "dddd222222222222222222222222222222222222222222222222222222222222"
    end
  end

  on_linux do
    on_arm do
      url "https://example.invalid/br-0.7.7-linux-arm64.tar.gz"
      sha256 "dddd333333333333333333333333333333333333333333333333333333333333"
    end
    on_intel do
      url "https://example.invalid/br-0.7.7-linux-x86_64.tar.gz"
      sha256 "dddd444444444444444444444444444444444444444444444444444444444444"
    end
  end
end
EOF

  cat >"$fx/Formula/acli.rb" <<'EOF'
class Acli < Formula
  desc "acli"
  homepage "https://example.invalid/acli"
  url "https://example.invalid/acli-0.2.0.tar.gz"
  sha256 "eeee111111111111111111111111111111111111111111111111111111111111"
  license "Apache-2.0"

  resource "guest-aarch64-linux-musl" do
    url "https://example.invalid/acli-guest-0.2.0-aarch64-unknown-linux-musl.tar.xz"
    sha256 "eeee222222222222222222222222222222222222222222222222222222222222"
  end

  resource "guest-x86_64-linux-musl" do
    url "https://example.invalid/acli-guest-0.2.0-x86_64-unknown-linux-musl.tar.xz"
    sha256 "eeee333333333333333333333333333333333333333333333333333333333333"
  end
end
EOF

  "$shell_bin" "$AUTOBUMP_SCRIPT" sync-lock "$fx/versions/aitools-lock.json" "$fx/Formula/br.rb" 0.7.7
  "$shell_bin" "$AUTOBUMP_SCRIPT" sync-lock "$fx/versions/aitools-lock.json" "$fx/Formula/acli.rb" 0.2.0

  "$shell_bin" "$LOCK_SCRIPT" --lockfile "$fx/versions/aitools-lock.json" --formula-dir "$fx/Formula" >/dev/null

  jq -e '
    ([.artifacts[] | select(.package == "br") | .version] | unique == ["0.7.7"])
    and ([.artifacts[] | select(.package == "acli") | .version] | unique == ["0.2.0"])
    and (.artifacts[] | select(.package == "acli" and .resource == "guest-aarch64-linux-musl") | .sha256 == "eeee222222222222222222222222222222222222222222222222222222222222")
  ' "$fx/versions/aitools-lock.json" >/dev/null

  # Verify autobump.sh rewrite updates main url + both guest musl resources + indented version lines offline via file:// fixtures.
  local files_dir="$BATS_TEST_TMPDIR/local-release-files"
  mkdir -p "$files_dir"
  printf 'acli-0.2.0-src\n' >"$files_dir/acli-0.2.0.tar.gz"
  printf 'acli-0.2.0-arm64\n' >"$files_dir/acli-guest-0.2.0-aarch64-unknown-linux-musl.tar.xz"
  printf 'acli-0.2.0-x86_64\n' >"$files_dir/acli-guest-0.2.0-x86_64-unknown-linux-musl.tar.xz"

  local rw_formula="$BATS_TEST_TMPDIR/acli-rewrite.rb"
  cat >"$rw_formula" <<EOF
class Acli < Formula
  desc "acli"
  url "file://${files_dir}/acli-0.1.0.tar.gz"
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "Apache-2.0"

  resource "guest-aarch64-linux-musl" do
    url "file://${files_dir}/acli-guest-0.1.0-aarch64-unknown-linux-musl.tar.xz"
    version "0.1.0"
    sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  end

  resource "guest-x86_64-linux-musl" do
    url "file://${files_dir}/acli-guest-0.1.0-x86_64-unknown-linux-musl.tar.xz"
    sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  end
end
EOF
  local rw_out="$BATS_TEST_TMPDIR/acli-rewritten.rb"
  "$shell_bin" "$AUTOBUMP_SCRIPT" rewrite "$rw_formula" 0.1.0 0.2.0 >"$rw_out"
  grep -Fq 'acli-0.2.0.tar.gz' "$rw_out"
  grep -Fq '    version "0.2.0"' "$rw_out"
  grep -Fq 'acli-guest-0.2.0-aarch64-unknown-linux-musl.tar.xz' "$rw_out"
  grep -Fq 'acli-guest-0.2.0-x86_64-unknown-linux-musl.tar.xz' "$rw_out"
  ! grep -Fq '0.1.0' "$rw_out"
  ! grep -Fq '0000000000000000000000000000000000000000000000000000000000000000' "$rw_out"
}

@test "bash 3.2: check-aitools-lock validates staged/present lockfiles, perturbations, and Cargo.lock statig pin" {
  run case_lock_verification_and_perturbations "$LOCK_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: autobump sync-lock co-bumps br multi-platform and acli guest musl resources" {
  run case_autobump_sync_lock "$LOCK_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 5+: check-aitools-lock validates staged/present lockfiles, perturbations, and Cargo.lock statig pin" {
  run case_lock_verification_and_perturbations "$LOCK_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: autobump sync-lock co-bumps br multi-platform and acli guest musl resources" {
  run case_autobump_sync_lock "$LOCK_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "repository versions/aitools-lock.json matches committed Formula/*.rb" {
  run "$LOCK_MODERN_BASH" "$LOCK_SCRIPT" --json
  [ "$status" -eq 0 ]
  jq -e '.ok == true and .checked == 17 and .failed == 0' <<<"$output"
}
