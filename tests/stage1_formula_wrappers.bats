#!/usr/bin/env bats
# Bats behavior, Bash 3.2/5+ compatibility, and ShellCheck suite for Stage-1
# hardened formula wrappers extracted directly from Formula/*.rb.

setup_file() {
  export WRAP_BASH32="${BATS_BASH32:-/bin/bash}"
  export WRAP_MODERN_BASH="${BATS_MODERN_BASH:-$(command -v bash)}"
  export WRAP_REPO_ROOT="${BATS_REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)}"
  export WRAP_HAS_BASH32=0

  local mod_ver=""
  mod_ver="$("$WRAP_MODERN_BASH" --version | awk 'NR == 1 { print; exit }')"
  [[ "$mod_ver" =~ version\ [5-9]\. ]] || {
    printf 'BATS_MODERN_BASH must identify Bash 5+ (got: %s)\n' "$mod_ver" >&2
    return 1
  }

  local b32_ver=""
  if [[ -x "$WRAP_BASH32" ]]; then
    b32_ver="$("$WRAP_BASH32" --version | awk 'NR == 1 { print; exit }')"
  fi
  if [[ "$b32_ver" =~ version\ 3\.2\. ]]; then
    WRAP_HAS_BASH32=1
  elif [[ "$(uname -s)" = "Darwin" ]]; then
    printf 'BATS_BASH32 must identify Bash 3.2 on Darwin (got: %s)\n' "${b32_ver:-missing}" >&2
    return 1
  fi
}

setup() {
  if [[ "$BATS_TEST_DESCRIPTION" == "bash 3.2:"* ]] && [[ "${WRAP_HAS_BASH32:-0}" -ne 1 ]]; then
    skip "macOS Bash 3.2 interpreter is not installed on $(uname -s)"
  fi
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_STATE_HOME="$HOME/.local/state"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$TMPDIR"
  export BATS_TEST_PIDS_FILE="$BATS_TEST_TMPDIR/bg.pids"
  : >"$BATS_TEST_PIDS_FILE"
}

teardown() {
  if [[ -n "${BATS_TEST_PIDS_FILE:-}" && -f "$BATS_TEST_PIDS_FILE" ]]; then
    local pid=""
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    done <"$BATS_TEST_PIDS_FILE"
  fi
}

extract_wrapper() {
  local formula="$1"
  local entry="$2"
  local stub_exec="$3"
  local out="$4"
  ruby -e '
    src = File.read(ARGV[0])
    stub_exec = ARGV[1]
    m = src.match(/<<~SH\n(.*?)\n[ \t]*SH/m)
    raise "No <<~SH heredoc found in #{ARGV[0]}" unless m
    lines = m[1].lines
    indent = lines.reject { |l| l.strip.empty? }.map { |l| l[/^\s*/].length }.min || 0
    body = lines.map { |l| l.length >= indent ? l[indent..] : l }.join
    body = body.gsub("\#{libexec}/\#{entry}", stub_exec)
    body = body.gsub(/#\{libexec\}\/bin\/nats-bind-preflight" "#\{libexec\}\/nats-server/, stub_exec)
    body = body.gsub(/#\{libexec\}\/[A-Za-z0-9._-]+/, stub_exec)
    File.write(ARGV[2], body)
  ' "$WRAP_REPO_ROOT/Formula/$formula" "$stub_exec" "$out"
  chmod 0755 "$out"
  : "$entry"
}

make_stub() {
  local stub="$1"
  cat >"$stub" <<'EOF'
#!/bin/sh
printf 'ENV:HTTP_HOST=%s\n' "${HTTP_HOST-<unset>}"
printf 'ENV:CONVERT_IMAGES=%s\n' "${CONVERT_IMAGES-<unset>}"
printf 'ENV:DO_NOT_TRACK=%s\n' "${DO_NOT_TRACK-<unset>}"
printf 'ENV:NATS_URL=%s\n' "${NATS_URL-<unset>}"
printf 'ENV:NATS_CONTEXT=%s\n' "${NATS_CONTEXT-<unset>}"
printf 'ENV:BD_DISABLE_METRICS=%s\n' "${BD_DISABLE_METRICS-<unset>}"
printf 'ENV:BD_DISABLE_EVENT_FLUSH=%s\n' "${BD_DISABLE_EVENT_FLUSH-<unset>}"
printf 'ENV:DOLT_METRICS_DISABLED=%s\n' "${DOLT_METRICS_DISABLED-<unset>}"
printf 'ARGC:%d\n' "$#"
for a in "$@"; do
  printf 'ARG:%s\n' "$a"
done
EOF
  chmod 0755 "$stub"
}

# Run command capturing combined stdout/stderr in CMD_OUT and asserting exit status.
assert_exit() {
  local want="$1"
  shift
  local rc=0
  CMD_OUT="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" -ne "$want" ]]; then
    printf 'Expected exit %d, got %d for: %s\nOutput:\n%s\n' "$want" "$rc" "$*" "$CMD_OUT" >&2
    return 1
  fi
}

assert_contains() {
  local needle="$1"
  if [[ "$CMD_OUT" != *"$needle"* ]]; then
    printf 'Expected output to contain %q\nOutput:\n%s\n' "$needle" "$CMD_OUT" >&2
    return 1
  fi
}

assert_not_contains() {
  local needle="$1"
  if [[ "$CMD_OUT" == *"$needle"* ]]; then
    printf 'Expected output NOT to contain %q\nOutput:\n%s\n' "$needle" "$CMD_OUT" >&2
    return 1
  fi
}

run_agent_mail_matrix() {
  local interp="$1"
  local stub="$BATS_TEST_TMPDIR/stub"
  local am="$BATS_TEST_TMPDIR/am"
  local mcp="$BATS_TEST_TMPDIR/mcp-agent-mail"
  make_stub "$stub"
  extract_wrapper "agent-mail.rb" "am" "$stub" "$am"
  extract_wrapper "agent-mail.rb" "mcp-agent-mail" "$stub" "$mcp"

  assert_exit 2 "$interp" "$am" self-update
  assert_contains "brew upgrade artagon/aitools/agent-mail"

  assert_exit 2 "$interp" "$am" update
  assert_exit 2 "$interp" "$am" -v self-update
  assert_exit 2 env AM_INTERFACE_MODE=cli "$interp" "$mcp" self-update
  assert_exit 2 env AM_INTERFACE_MODE=cli "$interp" "$mcp" -v update

  assert_exit 0 env -u HTTP_HOST -u CONVERT_IMAGES -u DO_NOT_TRACK "$interp" "$am" upgrade
  assert_contains "ENV:HTTP_HOST=127.0.0.1"
  assert_contains "ENV:CONVERT_IMAGES=false"
  assert_contains "ENV:DO_NOT_TRACK=1"
  assert_contains "ARG:upgrade"

  assert_exit 0 "$interp" "$am" help self-update
  assert_contains "ARG:help"

  assert_exit 0 "$interp" "$am" -- --self-update
  assert_contains "ARG:--self-update"

  assert_exit 0 "$interp" "$am" -h self-update

  assert_exit 0 env -u HTTP_HOST "$interp" "$mcp"
  assert_contains "ENV:HTTP_HOST=127.0.0.1"
  assert_contains "ARGC:0"

  assert_exit 0 env HTTP_HOST=::1 "$interp" "$mcp" serve
  assert_contains "ENV:HTTP_HOST=::1"
}

run_nats_matrix() {
  local interp="$1"
  local stub="$BATS_TEST_TMPDIR/stub"
  local nats="$BATS_TEST_TMPDIR/nats"
  make_stub "$stub"
  extract_wrapper "nats.rb" "nats" "$stub" "$nats"

  # (a) Clean env + no context.txt + no server/context flag -> inject 127.0.0.1:4222
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT -u DO_NOT_TRACK "$interp" "$nats" server info
  assert_contains "ENV:NATS_URL=nats://127.0.0.1:4222"
  assert_contains "ENV:DO_NOT_TRACK=1"

  # (b1) NATS_CONTEXT set with context.txt absent -> do NOT inject NATS_URL
  assert_exit 0 env -u NATS_URL NATS_CONTEXT=prod "$interp" "$nats" server info
  assert_contains "ENV:NATS_URL=<unset>"
  assert_contains "ENV:NATS_CONTEXT=prod"

  # (b2) context / ctx subcommands must NOT inject NATS_URL (prevents corrupting saved URLs)
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" context save prod --description updated
  assert_contains "ENV:NATS_URL=<unset>"

  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" context copy prod staging
  assert_contains "ENV:NATS_URL=<unset>"

  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" ctx info prod
  assert_contains "ENV:NATS_URL=<unset>"

  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" --trace context save prod --description updated
  assert_contains "ENV:NATS_URL=<unset>"

  # (b3) Explicit -s / --server / --context (before or after subcommand) -> do NOT inject
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" -s nats://10.0.0.1:4222 server info
  assert_contains "ENV:NATS_URL=<unset>"

  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" --server=nats://10.0.0.1:4222 server info
  assert_contains "ENV:NATS_URL=<unset>"

  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" pub s m --context prod
  assert_contains "ENV:NATS_URL=<unset>"

  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" pub s m -snats://10.0.0.1:4222
  assert_contains "ENV:NATS_URL=<unset>"

  # Non-target valued flag consuming -s must NOT suppress loopback injection
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" --user -s pub s m
  assert_contains "ENV:NATS_URL=nats://127.0.0.1:4222"

  # Flags after -- must NOT suppress loopback injection
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" pub s -- -s ignored
  assert_contains "ENV:NATS_URL=nats://127.0.0.1:4222"

  # Whitespace-only context.txt treated as empty -> inject loopback
  mkdir -p "$XDG_CONFIG_HOME/nats"
  printf '   \n\t ' >"$XDG_CONFIG_HOME/nats/context.txt"
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" server info
  assert_contains "ENV:NATS_URL=nats://127.0.0.1:4222"

  # Non-empty context.txt -> preserve context (no NATS_URL injection)
  printf 'broker-b\n' >"$XDG_CONFIG_HOME/nats/context.txt"
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" server info
  assert_contains "ENV:NATS_URL=<unset>"

  # --no-context ignores saved context.txt -> inject loopback
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$interp" "$nats" --no-context server info
  assert_contains "ENV:NATS_URL=nats://127.0.0.1:4222"

  # Explicit NATS_URL preserved
  assert_exit 0 env -u NATS_CONTEXT NATS_URL=nats://10.0.0.9:4222 "$interp" "$nats" server info
  assert_contains "ENV:NATS_URL=nats://10.0.0.9:4222"
}

run_br_matrix() {
  local interp="$1"
  local stub="$BATS_TEST_TMPDIR/stub"
  local br="$BATS_TEST_TMPDIR/br"
  make_stub "$stub"
  extract_wrapper "br.rb" "br" "$stub" "$br"

  assert_exit 2 "$interp" "$br" upgrade
  assert_contains "brew upgrade artagon/aitools/br"

  assert_exit 2 "$interp" "$br" --db "$BATS_TEST_TMPDIR/a.db" --actor tester --format json --lock-timeout 5000 upgrade
  assert_exit 2 "$interp" "$br" --db="$BATS_TEST_TMPDIR/a.db" -vv upgrade --force

  assert_exit 0 "$interp" "$br" help upgrade
  assert_contains "ARG:help"

  assert_exit 0 "$interp" "$br" -h upgrade

  assert_exit 0 "$interp" "$br" -- upgrade
  assert_contains "ARG:upgrade"

  assert_exit 0 env -u DO_NOT_TRACK "$interp" "$br" list --json
  assert_contains "ENV:DO_NOT_TRACK=1"
  assert_contains "ARG:list"

  assert_exit 0 "$interp" "$br"
  assert_contains "ARGC:0"
}

run_bd_matrix() {
  local interp="$1"
  local stub="$BATS_TEST_TMPDIR/stub"
  local bd="$BATS_TEST_TMPDIR/bd"
  make_stub "$stub"
  extract_wrapper "bd.rb" "bd" "$stub" "$bd"

  assert_exit 0 env BD_DISABLE_METRICS=0 BD_DISABLE_EVENT_FLUSH=0 DOLT_METRICS_DISABLED=0 DO_NOT_TRACK=0 "$interp" "$bd" list --json
  assert_contains "ENV:BD_DISABLE_METRICS=1"
  assert_contains "ENV:BD_DISABLE_EVENT_FLUSH=1"
  assert_contains "ENV:DOLT_METRICS_DISABLED=1"
  assert_contains "ENV:DO_NOT_TRACK=1"

  # Verify bd update and bd upgrade are preserved (not blocked).
  assert_exit 0 "$interp" "$bd" update test-1 --status in_progress
  assert_contains "ARG:update"

  assert_exit 0 "$interp" "$bd" upgrade --check
  assert_contains "ARG:upgrade"
}

run_nats_server_wrapper_matrix() {
  local interp="$1"
  local stub="$BATS_TEST_TMPDIR/stub"
  local ns="$BATS_TEST_TMPDIR/nats-server"
  make_stub "$stub"
  extract_wrapper "nats-server.rb" "nats-server" "$stub" "$ns"

  assert_exit 0 env -u DO_NOT_TRACK "$interp" "$ns"
  assert_contains "ENV:DO_NOT_TRACK=1"
  assert_contains "ARGC:0"

  assert_exit 0 "$interp" "$ns" -p 14222 --name "broker one"
  assert_contains "ARG:-p"
  assert_contains "ARG:14222"
  assert_contains "ARG:broker one"
}

pick_free_port() {
  ruby -rsocket -e 's = TCPServer.new("127.0.0.1", 0); puts s.addr[1]; s.close'
}

wait_for_port() {
  local port="$1"
  ruby -rsocket -e '
    port = Integer(ARGV[0])
    50.times do
      s = TCPSocket.new("127.0.0.1", port)
      s.close
      exit 0
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      sleep 0.1
    end
    exit 1
  ' "$port"
}

@test "shellcheck --enable=all passes on every extracted Stage-1 formula wrapper" {
  local stub="$BATS_TEST_TMPDIR/stub"
  make_stub "$stub"
  local spec="" f="" e="" w=""
  for spec in "agent-mail.rb:am" "agent-mail.rb:mcp-agent-mail" "nats.rb:nats" "nats-server.rb:nats-server" "br.rb:br" "bd.rb:bd"; do
    f="${spec%%:*}"
    e="${spec#*:}"
    w="$BATS_TEST_TMPDIR/${e}.sh"
    extract_wrapper "$f" "$e" "$stub" "$w"
    shellcheck --enable=all "$w"
  done
}

@test "bash 3.2: agent-mail wrappers block self-update|update and preserve upgrade/server" {
  run_agent_mail_matrix "$WRAP_BASH32"
}

@test "bash 5+: agent-mail wrappers block self-update|update and preserve upgrade/server" {
  run_agent_mail_matrix "$WRAP_MODERN_BASH"
}

@test "bash 3.2: nats wrapper loopback fallback and context precedence" {
  run_nats_matrix "$WRAP_BASH32"
}

@test "bash 5+: nats wrapper loopback fallback and context precedence" {
  run_nats_matrix "$WRAP_MODERN_BASH"
}

@test "bash 3.2: br wrapper blocks upgrade across global flags and allows help/normal commands" {
  run_br_matrix "$WRAP_BASH32"
}

@test "bash 5+: br wrapper blocks upgrade across global flags and allows help/normal commands" {
  run_br_matrix "$WRAP_MODERN_BASH"
}

@test "bash 3.2: bd wrapper unconditionally forces all four privacy env vars and preserves update/upgrade" {
  run_bd_matrix "$WRAP_BASH32"
}

@test "bash 5+: bd wrapper unconditionally forces all four privacy env vars and preserves update/upgrade" {
  run_bd_matrix "$WRAP_MODERN_BASH"
}

@test "bash 3.2: nats-server wrapper sets DO_NOT_TRACK and forwards arguments intact" {
  run_nats_server_wrapper_matrix "$WRAP_BASH32"
}

@test "bash 5+: nats-server wrapper sets DO_NOT_TRACK and forwards arguments intact" {
  run_nats_server_wrapper_matrix "$WRAP_MODERN_BASH"
}

@test "live two-broker: nats wrapper routes NATS_CONTEXT (context.txt absent), saved context.txt, context save/copy, and -s" {
  if [[ -z "${BATS_NATS_BIN:-}" || -z "${BATS_NATS_SERVER_BIN:-}" ]]; then
    skip "Set BATS_NATS_BIN and BATS_NATS_SERVER_BIN to run live two-broker test"
  fi
  [[ -x "$BATS_NATS_BIN" && -x "$BATS_NATS_SERVER_BIN" ]]

  local wrapped_nats="$BATS_TEST_TMPDIR/wrapped-nats"
  extract_wrapper "nats.rb" "nats" "$BATS_NATS_BIN" "$wrapped_nats"

  local port_a="" port_b="" pid_a="" pid_b=""
  port_a="$(pick_free_port)"
  port_b="$(pick_free_port)"

  "$BATS_NATS_SERVER_BIN" -a 127.0.0.1 -p "$port_a" -n broker-a </dev/null >/dev/null 2>&1 3>&- &
  pid_a=$!
  printf '%s\n' "$pid_a" >>"$BATS_TEST_PIDS_FILE"
  "$BATS_NATS_SERVER_BIN" -a 127.0.0.1 -p "$port_b" -n broker-b </dev/null >/dev/null 2>&1 3>&- &
  pid_b=$!
  printf '%s\n' "$pid_b" >>"$BATS_TEST_PIDS_FILE"

  wait_for_port "$port_a"
  wait_for_port "$port_b"

  # Save contexts without selecting (context.txt remains absent!).
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$WRAP_BASH32" "$wrapped_nats" context save broker-a --server="nats://127.0.0.1:${port_a}"
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$WRAP_BASH32" "$wrapped_nats" context save broker-b --server="nats://127.0.0.1:${port_b}"
  [[ ! -e "$XDG_CONFIG_HOME/nats/context.txt" ]]

  # Updating description and copying context must preserve port_b (not overwrite to :4222).
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$WRAP_BASH32" "$wrapped_nats" context save broker-b --description="updated-b"
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$WRAP_BASH32" "$wrapped_nats" context copy broker-b broker-b-copy
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$WRAP_BASH32" "$wrapped_nats" context info broker-b-copy
  assert_contains "nats://127.0.0.1:${port_b}"
  assert_not_contains "WARNING: Shell environment overrides"

  # NATS_CONTEXT=broker-b with context.txt absent MUST hit broker-b (not :4222).
  assert_exit 0 env -u NATS_URL NATS_CONTEXT=broker-b "$WRAP_BASH32" "$wrapped_nats" rtt 1
  assert_contains "127.0.0.1:${port_b}"

  # Saved context.txt selecting broker-a MUST hit broker-a.
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$WRAP_BASH32" "$wrapped_nats" context select broker-a
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$WRAP_BASH32" "$wrapped_nats" rtt 1
  assert_contains "127.0.0.1:${port_a}"

  # Explicit -s overrides saved context.txt.
  assert_exit 0 env -u NATS_URL -u NATS_CONTEXT "$WRAP_BASH32" "$wrapped_nats" -s "nats://127.0.0.1:${port_b}" rtt 1
  assert_contains "127.0.0.1:${port_b}"
}
