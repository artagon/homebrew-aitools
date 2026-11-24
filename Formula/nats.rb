class Nats < Formula
  desc "Utility to interact with and manage NATS messaging systems"
  homepage "https://github.com/nats-io/natscli"
  url "https://github.com/nats-io/natscli/archive/refs/tags/v0.5.2.tar.gz"
  sha256 "6a735b879a19a7abaa4b45e512f23ddb7df6e8f1cd14b32091cd8568e4e94f63"
  license "Apache-2.0"
  revision 1
  head "https://github.com/nats-io/natscli.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  deny_network_access! [:build, :postinstall]

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args(output: libexec/"nats", ldflags: "-X main.version=#{version}"), "./nats"
    chmod 0755, libexec/"nats"

    (bin/"nats").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      first_cmd=""
      has_endpoint_flag=0
      has_no_context=0
      skip_next=0
      for arg in "$@"; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        case "${arg}" in
          --)
            break
            ;;
          -s | --server | --context)
            has_endpoint_flag=1
            skip_next=1
            ;;
          -s?* | --server=* | --context=*)
            has_endpoint_flag=1
            ;;
          --no-context)
            has_no_context=1
            ;;
          --user | --password | --token | --connection-name | --creds | --nkey | \
          --jwt | --seed | --tlscert | --tlskey | --tlsca | --timeout | \
          --socks-proxy | --js-api-prefix | --js-event-prefix | --js-domain | \
          --domain | --inbox-prefix | --colors)
            skip_next=1
            ;;
          -*)
            ;;
          *)
            if [[ -z "${first_cmd}" ]]; then
              first_cmd="${arg}"
            fi
            ;;
        esac
      done

      has_saved_context=0
      if [[ "${has_no_context}" -eq 0 ]]; then
        ctx_base="${XDG_CONFIG_HOME:-${HOME:+${HOME}/.config}}"
        if [[ -n "${ctx_base}" ]]; then
          ctx_file="${ctx_base}/nats/context.txt"
          if [[ -f "${ctx_file}" && -r "${ctx_file}" ]]; then
            ctx_val="$(tr -d '[:space:]' <"${ctx_file}" 2>/dev/null || true)"
            if [[ -n "${ctx_val}" ]]; then
              has_saved_context=1
            fi
          fi
        fi
      fi

      if [[ "${first_cmd}" != "context" && "${first_cmd}" != "ctx" && "${has_endpoint_flag}" -eq 0 && -z "${NATS_URL:-}" && -z "${NATS_CONTEXT:-}" && "${has_saved_context}" -eq 0 ]]; then
        export NATS_URL="nats://127.0.0.1:4222"
      fi
      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

      exec "#{libexec}/nats" "$@"
    SH
    chmod 0755, bin/"nats"

    generate_completions_from_executable(libexec/"nats",
                                         shell_parameter_format: "--completion-script-",
                                         shells:                 [:bash, :zsh])

    (pkgshare/"skills/nats/SKILL.md").write <<~EOS
      ---
      name: nats
      description: Operate NATS messaging, JetStream streams/consumers, KV buckets, and contexts with the hardened nats CLI (v0.5.x). Use when publishing/subscribing messages, inspecting JetStream state, or managing NATS CLI contexts.
      ---

      # NATS CLI Administration (`nats`)

      ## Core Commands

      - Manage named contexts (stored under `${XDG_CONFIG_HOME:-~/.config}/nats/context`):
        `nats context save local --server=nats://127.0.0.1:4222 --select`
        `nats context ls`
      - Publish, subscribe, and request-reply:
        `nats pub demo.subject "hello"`
        `nats sub "demo.>" --count 1`
        `nats req service.ping "ping"`
      - Inspect JetStream streams and KV stores:
        `nats stream ls`
        `nats kv ls`

      ## Tap Hardening Notes

      - Defaults `NATS_URL=nats://127.0.0.1:4222` and `DO_NOT_TRACK=1` only when no `-s`/`--server`/`--context` flag, `NATS_URL`, `NATS_CONTEXT`, or non-empty `${XDG_CONFIG_HOME:-~/.config}/nats/context.txt` is set (and skips `NATS_URL` injection for `nats context`/`ctx` subcommands).
      - Qualify upgrades with `brew upgrade artagon/aitools/nats`.
    EOS
  end

  def caveats
    <<~EOS
      Because `homebrew/core` also provides a `nats` formula, always qualify this
      tap when installing or upgrading:
        brew install artagon/aitools/nats
        brew upgrade artagon/aitools/nats

      The `nats` wrapper defaults `NATS_URL=nats://127.0.0.1:4222` and
      `DO_NOT_TRACK=1` only when no `-s`/`--server`/`--context` flag, `NATS_URL`,
      `NATS_CONTEXT`, or non-empty `${XDG_CONFIG_HOME:-~/.config}/nats/context.txt`
      is present (and leaves `nats context`/`ctx` subcommands untouched).

      A companion agent skill is staged passively under:
        #{opt_pkgshare}/skills/nats

      This formula does not modify any agent configuration files.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    assert_match version.to_s, shell_output("#{bin}/nats --version")
    assert_path_exists bash_completion/"nats"
    assert_path_exists zsh_completion/"_nats"
    assert_path_exists pkgshare/"skills/nats/SKILL.md"

    probe_src = (bin/"nats").read
    refute_nil probe_src.sub!(%Q(exec "#{libexec}/nats" "$@"), "exec /usr/bin/env")
    probe = testpath/"nats-env-probe"
    probe.write(probe_src)
    chmod 0755, probe

    default_env = shell_output("env -u NATS_URL -u NATS_CONTEXT #{probe} server info")
    assert_match(%r{^NATS_URL=nats://127\.0\.0\.1:4222$}, default_env)
    assert_match(/^DO_NOT_TRACK=1$/, default_env)

    ctx_env = shell_output("env -u NATS_URL NATS_CONTEXT=prod #{probe} server info")
    refute_match(/^NATS_URL=/, ctx_env)

    flag_env = shell_output("env -u NATS_URL -u NATS_CONTEXT #{probe} pub demo hi --context prod")
    refute_match(/^NATS_URL=/, flag_env)

    context_cmd_env = shell_output("env -u NATS_URL -u NATS_CONTEXT #{probe} context copy prod staging")
    refute_match(/^NATS_URL=/, context_cmd_env)

    post_dd_env = shell_output("env -u NATS_URL -u NATS_CONTEXT #{probe} pub demo -- -s ignored")
    assert_match(%r{^NATS_URL=nats://127\.0\.0\.1:4222$}, post_dd_env)

    # Verify context save/update/copy/info preserve a non-default URL without
    # injecting NATS_URL=nats://127.0.0.1:4222 or triggering env-override warnings.
    system bin/"nats", "context", "save", "custom", "--server=nats://127.0.0.1:14222", "--description=initial"
    system bin/"nats", "context", "save", "custom", "--description=updated"
    system bin/"nats", "context", "copy", "custom", "custom-copy"
    copy_info = shell_output("env -u NATS_URL -u NATS_CONTEXT #{bin}/nats context info custom-copy 2>&1")
    assert_match "nats://127.0.0.1:14222", copy_info
    refute_match "WARNING: Shell environment overrides", copy_info

    system bin/"nats", "context", "select", "custom"
    assert_match "custom", shell_output("#{bin}/nats context ls")

    saved_env = shell_output("env -u NATS_URL -u NATS_CONTEXT #{probe} server info")
    refute_match(/^NATS_URL=/, saved_env)

    no_ctx_env = shell_output("env -u NATS_URL -u NATS_CONTEXT #{probe} --no-context server info")
    assert_match(%r{^NATS_URL=nats://127\.0\.0\.1:4222$}, no_ctx_env)

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
