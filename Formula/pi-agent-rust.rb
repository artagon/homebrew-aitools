class PiAgentRust < Formula
  desc "Safe-Rust AI coding agent CLI with hashline editing"
  homepage "https://github.com/Dicklesworthstone/pi_agent_rust"
  # MIT License with OpenAI/Anthropic Rider; full text installed to prefix/LICENSE.
  license :cannot_represent

  livecheck do
    url :homepage
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/Dicklesworthstone/pi_agent_rust/releases/download/v0.8.0/pi-darwin-arm64.tar.xz"
      sha256 "9999ee5b05283a79b277162f739df9ff36b2ff0f8dca6cf1d6cc4e1aae5d05d9"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/pi_agent_rust/releases/download/v0.8.0/pi-darwin-amd64.tar.xz"
      sha256 "758e34ac63f4ba1c70d07609581913861f7d5d1efbf1e9c3be4b9deebb5fcfbd"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Dicklesworthstone/pi_agent_rust/releases/download/v0.8.0/pi-linux-arm64.tar.xz"
      sha256 "3276504d19554d7aa8af22703674186b9887c48cffc1cd1238b7bf523100abf9"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/pi_agent_rust/releases/download/v0.8.0/pi-linux-amd64.tar.xz"
      sha256 "c04e7f87391becb17cb1ec7544d0fd767231dfb5a8361644ea8870ba3d39056d"
    end
  end

  conflicts_with "cln", because: "both install `pi` binaries"
  conflicts_with "pi-coding-agent", because: "both install `pi` binaries"

  resource "skill_main" do
    url "https://raw.githubusercontent.com/Dicklesworthstone/pi_agent_rust/v0.8.0/.claude/skills/pi-agent-rust/SKILL.md"
    sha256 "763fa8138ba6b6e12525325e3dd6a9618bb8657c66f9b96f3749f65bbf644589"
  end

  resource "skill_commands" do
    url "https://raw.githubusercontent.com/Dicklesworthstone/pi_agent_rust/v0.8.0/.claude/skills/pi-agent-rust/references/COMMANDS.md"
    sha256 "3e8917454ed1ae0f56d00857472b98acace83bcfe1d1c427e2e2e62267e8f5fe"
  end

  resource "skill_playbooks" do
    url "https://raw.githubusercontent.com/Dicklesworthstone/pi_agent_rust/v0.8.0/.claude/skills/pi-agent-rust/references/DEBUGGING-PLAYBOOKS.md"
    sha256 "9031fa6909b43e683053fe561891364088547548c5f0a10d6b0de533ba6d4b92"
  end

  def install
    libexec.install "pi"
    chmod 0755, libexec/"pi"
    doc.install "README.md"
    prefix.install "LICENSE"

    with_env(HOME: buildpath.to_s, XDG_CONFIG_HOME: (buildpath/".config").to_s) do
      generate_completions_from_executable(libexec/"pi", "completions")
    end

    skill_dir = pkgshare/"skills/pi-agent-rust"
    resource("skill_main").stage { skill_dir.install "SKILL.md" }
    resource("skill_commands").stage { (skill_dir/"references").install "COMMANDS.md" }
    resource("skill_playbooks").stage { (skill_dir/"references").install "DEBUGGING-PLAYBOOKS.md" }

    (pkgshare/"examples/subscription-only/models.json").write <<~JSON
      {
        "providers": {
          "magpie": {
            "baseUrl": "http://127.0.0.1:3425/v1",
            "apiKey": "magpie-pi-rust",
            "api": "openai-completions",
            "authHeader": true,
            "headers": {
              "User-Agent": "pi-agent-rust"
            },
            "models": [
              {
                "id": "group/sub-coder",
                "name": "Magpie Subscription Coder (Claude Primary)",
                "api": "anthropic-messages",
                "baseUrl": "http://127.0.0.1:3425",
                "reasoning": true,
                "input": ["text", "image"],
                "contextWindow": 200000,
                "maxTokens": 16384
              },
              {
                "id": "group/sub-subagent",
                "name": "Magpie Subscription Subagent (Codex Responses)",
                "api": "openai-responses",
                "reasoning": true,
                "input": ["text", "image"],
                "contextWindow": 200000,
                "maxTokens": 16384
              },
              {
                "id": "group/sub-smol",
                "name": "Magpie Subscription Smol (Copilot/Gemini Fast)",
                "api": "openai-completions",
                "reasoning": true,
                "input": ["text"],
                "contextWindow": 128000,
                "maxTokens": 8192,
                "compat": {
                  "supports_store": false,
                  "supports_developer_role": true,
                  "supports_reasoning_effort": true,
                  "supports_usage_in_streaming": true,
                  "supports_parallel_tool_calls": true,
                  "max_tokens_field": "max_completion_tokens"
                }
              }
            ]
          }
        }
      }
    JSON

    (pkgshare/"examples/subscription-only/settings.json").write <<~JSON
      {
        "defaultProvider": "magpie",
        "defaultModel": "group/sub-coder",
        "defaultThinkingLevel": "medium"
      }
    JSON

    pi_bin = libexec/"pi"
    %w[pi rpi].each do |cmd|
      (bin/cmd).write <<~SH
        #!/bin/bash
        # Target contract: macOS /bin/bash 3.2+ wrapper.
        set -euo pipefail

        export PI_SKIP_VERSION_CHECK="${PI_SKIP_VERSION_CHECK:-1}"
        export DO_NOT_TRACK="${DO_NOT_TRACK:-true}"
        export PI_SUBAGENT_PI_BINARY="${PI_SUBAGENT_PI_BINARY:-#{opt_bin}/pi}"

        seen_subcmd=0
        expect_value=0
        for arg in "$@"; do
          if [[ "${expect_value}" -eq 1 ]]; then
            expect_value=0
            continue
          fi
          case "${arg}" in
            --)
              break
              ;;
            --api-key|--api-key=*)
              if [[ "${PI_ALLOW_API_KEYS:-0}" != "1" ]]; then
                printf '%s\\n' "Error: --api-key is disabled in subscription-only mode. Use '/login' OAuth subscriptions or route through local magpie (set PI_ALLOW_API_KEYS=1 to override)." >&2
                exit 2
              fi
              if [[ "${arg}" = "--api-key" ]]; then
                expect_value=1
              fi
              ;;
            --mode|--models|--extension|-e|--skill|--prompt-template|--theme|--theme-path|--session|--session-workdir|--session-dir|--session-durability|--model|--smol|--slow|--plan|--provider|--thinking|--system-prompt|--append-system-prompt|--export|--tools|--mcp-config|--extension-policy|--repair-policy|--max-tool-iterations|--max-time|--warn-cost|--max-cost|--add-dir|--fetch-models)
              expect_value=1
              ;;
            -*)
              ;;
            *)
              if [[ "${seen_subcmd}" -eq 0 ]]; then
                seen_subcmd=1
                if [[ "${arg}" = "self-update" ]]; then
                  printf '%s\\n' "Error: Homebrew manages pi-agent-rust upgrades. Run: brew upgrade artagon/aitools/pi-agent-rust" >&2
                  exit 2
                fi
              fi
              ;;
          esac
        done

        if [[ "${PI_ALLOW_API_KEYS:-0}" != "1" ]]; then
          for var_name in $(compgen -v); do
            case "${var_name}" in
              *_API_KEY|ABLIT_KEY|AWS_BEARER_TOKEN_BEDROCK|CLOUDFLARE_API_TOKEN|CLOUDFLARE_AUTH_TOKEN|HF_TOKEN|HUGGINGFACE_HUB_TOKEN|MODAL_PROXY_TOKEN|SCW_SECRET_KEY|SNOWFLAKE_PAT)
                unset "${var_name}"
                ;;
            esac
          done
        fi

        exec "#{pi_bin}" "$@"
      SH
      chmod 0755, bin/cmd
    end
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `pi self-update` or `rpi self-update`.
      Upgrade with:
        brew upgrade artagon/aitools/pi-agent-rust

      Both `pi` and the compatibility alias `rpi` run in CLI-subscription-only
      mode by default:
        - Startup version checks and telemetry (`PI_SKIP_VERSION_CHECK=1`,
          `DO_NOT_TRACK=true`) are disabled.
        - Ambient `*_API_KEY` environment variables are scrubbed and `--api-key`
          is blocked unless `PI_ALLOW_API_KEYS=1` is explicitly set.

      Authenticate with OAuth CLI subscriptions inside `pi`/`rpi` (`/login`),
      or wire `~/.pi/agent/` through `artagon/aitools/magpie` (`127.0.0.1:3425`)
      using the subscription-only templates staged under:
        #{opt_pkgshare}/examples/subscription-only

      Bundled agent skill files are installed under:
        #{opt_pkgshare}/skills/pi-agent-rust

      This formula does not modify any live agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    assert_match version.to_s, shell_output("#{bin}/pi --version")
    assert_match version.to_s, shell_output("#{bin}/rpi --version")

    assert_match "brew upgrade artagon/aitools/pi-agent-rust",
                 shell_output("#{bin}/pi self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/pi-agent-rust",
                 shell_output("#{bin}/rpi self-update 2>&1", 2)
    assert_match "subscription-only mode",
                 shell_output("#{bin}/pi --api-key sk-test 2>&1", 2)

    assert_path_exists prefix/"LICENSE"
    assert_path_exists pkgshare/"skills/pi-agent-rust/SKILL.md"
    assert_path_exists pkgshare/"examples/subscription-only/models.json"
    assert_path_exists pkgshare/"examples/subscription-only/settings.json"
  end
end
