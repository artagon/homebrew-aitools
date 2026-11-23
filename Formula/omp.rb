class Omp < Formula
  desc "Terminal AI coding agent with Rust native core, LSP, and DAP"
  homepage "https://omp.sh"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/omp-19.1.1"
    rebuild 1
    sha256 arm64_tahoe:  "50f3340a0de4936384872b061660cfd2fc06f00d5792a473da533ce460dcf45f"
    sha256 arm64_linux:  "5928ca88f2738a7ea519141404efd2da1a56e2be1196e11a34d23ce64a59d522"
    sha256 x86_64_linux: "a267f62f7cce9a1ed58b0a7a59007080892d5fac83a63b06bd2620154d71f60a"
  end

  on_macos do
    on_arm do
      url "https://github.com/can1357/oh-my-pi/releases/download/v19.1.1/omp-darwin-arm64"
      sha256 "d5a3324acd98375a01698a1b0c018be48caed2956c8aa9044ad137fe43bc0400"
    end
    on_intel do
      url "https://github.com/can1357/oh-my-pi/releases/download/v19.1.1/omp-darwin-x64"
      sha256 "6ffecb22a9fe01a98f90f91a2ef04a697850a23bf4dde83adad2fe80e51a8353"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/can1357/oh-my-pi/releases/download/v19.1.1/omp-linux-arm64"
      sha256 "f022f720c4899eb24c6e5e34dcbbae98ae05f5532bb03e97dffc02cfc8dd9a6f"
    end
    on_intel do
      url "https://github.com/can1357/oh-my-pi/releases/download/v19.1.1/omp-linux-x64"
      sha256 "04e9490f9394da6d6804474cc2e41eb3d18f8e26215df4b34bdd4ad4c0d8a401"
    end
  end

  resource "license" do
    url "https://github.com/can1357/oh-my-pi/releases/download/v19.1.1/LICENSE"
    sha256 "16c45f9d667442781f03fa198914cc39abcaa48ec5ed8f644643e554ca2fbf63"
  end

  def install
    libexec.install Dir["omp-*"].first => "omp"
    chmod 0755, libexec/"omp"
    resource("license").stage { prefix.install "LICENSE" }

    with_env(
      HOME:            buildpath.to_s,
      XDG_CONFIG_HOME: (buildpath/".config").to_s,
      XDG_CACHE_HOME:  (buildpath/".cache").to_s,
      XDG_DATA_HOME:   (buildpath/".local/share").to_s,
      XDG_STATE_HOME:  (buildpath/".local/state").to_s,
    ) do
      generate_completions_from_executable(libexec/"omp", "completions")
    end

    # Process-level policy overlay disabling startup update checks, background
    # auto-updates, and OpenTelemetry export by default.
    (libexec/"homebrew-policy.yml").write <<~YAML
      startup:
        checkUpdate: false
      update:
        auto: false
      telemetry:
        otlpExportEnabled: false
    YAML

    # Ready-to-copy CLI-subscription-only configs wired to local loopback Magpie.
    (pkgshare/"examples/subscription-only/models.yml").write <<~YAML
      # Copy to ~/.omp/agent/models.yml to route omp through local magpie
      # backed exclusively by CLI subscriptions (no vendor API keys).
      providers:
        magpie:
          baseUrl: http://127.0.0.1:3425/v1
          apiKey: magpie-omp
          auth: apiKey
          authHeader: true
          headers:
            User-Agent: omp/18
          models:
            - id: group/sub-coder
              name: "Magpie Subscription Coder (Claude Primary)"
              api: anthropic-messages
              baseUrl: http://127.0.0.1:3425
              reasoning: true
              input: [text, image]
              contextWindow: 200000
              maxTokens: 16384
              compat:
                supportsEagerToolInputStreaming: true

            - id: group/sub-architect
              name: "Magpie Subscription Architect (Opus Primary)"
              api: anthropic-messages
              baseUrl: http://127.0.0.1:3425
              reasoning: true
              input: [text, image]
              contextWindow: 200000
              maxTokens: 32000
              compat:
                supportsEagerToolInputStreaming: true

        magpie-sub:
          baseUrl: http://127.0.0.1:3425/v1
          apiKey: magpie-omp-subagent
          auth: apiKey
          authHeader: true
          headers:
            User-Agent: omp-subagent/18
          models:
            - id: group/sub-subagent
              name: "Magpie Subscription Subagents (Codex/Responses)"
              api: openai-responses
              reasoning: true
              input: [text, image]
              contextWindow: 200000
              maxTokens: 16384
              compat:
                statefulResponses: false

            - id: group/sub-smol
              name: "Magpie Subscription Smol (Copilot/Gemini Fast)"
              api: openai-completions
              reasoning: true
              input: [text]
              contextWindow: 128000
              maxTokens: 8192
              compat:
                supportsStore: false
                supportsDeveloperRole: true
                supportsReasoningEffort: true
                supportsUsageInStreaming: true
                maxTokensField: max_completion_tokens
    YAML

    (pkgshare/"examples/subscription-only/config.yml").write <<~YAML
      # Copy to ~/.omp/agent/config.yml after setting up magpie subscription groups.
      modelRoles:
        default: magpie/group/sub-coder
        plan: magpie/group/sub-architect:high
        slow: magpie/group/sub-architect:xhigh
        advisor: magpie/group/sub-architect:high
        task: magpie-sub/group/sub-subagent:medium
        smol: magpie-sub/group/sub-smol:low
        commit: magpie-sub/group/sub-smol:minimal
        tiny: magpie-sub/group/sub-smol:off
        memory: magpie-sub/group/sub-smol:off

      retry:
        fallbackChains:
          task:
            - "@smol"
          tiny: []

      task:
        batch: true
        maxConcurrency: 8
        agentCompactionThresholdOverrides:
          scout: "75%"
          task: "75%"

      compaction:
        enabled: true
        asyncEnabled: true
        thresholdPercent: 80
        modelThresholds:
          "magpie/group/*": "75%"
          "magpie-sub/group/*": "75%"

      cycleOrder:
        - smol
        - default
        - slow

      enabledModels:
        - magpie/**
        - magpie-sub/**
    YAML

    policy_file = libexec/"homebrew-policy.yml"
    omp_bin = libexec/"omp"

    (bin/"omp").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export OTEL_SDK_DISABLED="${OTEL_SDK_DISABLED:-true}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-true}"
      export PI_AUTO_QA="${PI_AUTO_QA:-0}"
      export PI_SPOTLIGHT_EXPERIMENT="${PI_SPOTLIGHT_EXPERIMENT:-0}"

      if [[ -n "${PI_CONFIG_FILES:-}" ]]; then
        export PI_CONFIG_FILES="#{policy_file}:${PI_CONFIG_FILES}"
      else
        export PI_CONFIG_FILES="#{policy_file}"
      fi

      seen_subcmd=0
      subcmd=""
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
            if [[ "${OMP_ALLOW_API_KEYS:-0}" != "1" ]]; then
              printf '%s\\n' "Error: --api-key is disabled in subscription-only mode. Sign in via 'omp auth-broker login <provider>' or route through local magpie (set OMP_ALLOW_API_KEYS=1 to override)." >&2
              exit 2
            fi
            if [[ "${arg}" = "--api-key" ]]; then
              expect_value=1
            fi
            ;;
          --include-env)
            if [[ "${subcmd}" = "auth-broker" && "${OMP_ALLOW_API_KEYS:-0}" != "1" ]]; then
              printf '%s\\n' "Error: --include-env is disabled in subscription-only mode (set OMP_ALLOW_API_KEYS=1 to override)." >&2
              exit 2
            fi
            ;;
          --config|--model|--provider|--thinking|--mode|--session|--profile|--smol|--slow|--plan|--fork|--service-tier)
            expect_value=1
            ;;
          -*)
            ;;
          *)
            if [[ "${seen_subcmd}" -eq 0 ]]; then
              seen_subcmd=1
              subcmd="${arg}"
              if [[ "${arg}" = "update" ]]; then
                printf '%s\\n' "Error: Homebrew manages omp upgrades. Run: brew upgrade artagon/aitools/omp" >&2
                exit 2
              fi
            fi
            ;;
        esac
      done

      # Scrub ambient vendor API keys unless explicitly opted in so omp uses CLI
      # OAuth subscriptions (`omp auth-broker login`) or local loopback magpie only.
      if [[ "${OMP_ALLOW_API_KEYS:-0}" != "1" ]]; then
        for var_name in $(compgen -v); do
          case "${var_name}" in
            *_API_KEY|ABLIT_KEY|AWS_BEARER_TOKEN_BEDROCK|CLOUDFLARE_API_TOKEN|CLOUDFLARE_AUTH_TOKEN|HF_TOKEN|HUGGINGFACE_HUB_TOKEN|MODAL_PROXY_TOKEN|SCW_SECRET_KEY|SNOWFLAKE_PAT)
              unset "${var_name}"
              ;;
          esac
        done
      fi

      exec "#{omp_bin}" "$@"
    SH
    chmod 0755, bin/"omp"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `omp update`. Use:
        brew upgrade artagon/aitools/omp

      This wrapper runs `omp` in CLI-subscription-only mode by default:
        - Startup update checks, auto-updates, OTel export, AutoQA, and cloud
          Spotlight experiments are disabled.
        - Ambient `*_API_KEY` environment variables are scrubbed and `--api-key`
          is blocked unless `OMP_ALLOW_API_KEYS=1` is explicitly set.

      Authenticate with CLI subscriptions directly (no API keys):
        omp auth-broker login anthropic
        omp auth-broker login openai-codex
        omp auth-broker login github-copilot
        omp auth-broker login google-gemini-cli

      Or wire `omp` through `artagon/aitools/magpie` (`127.0.0.1:3425`) using:
        magpie oh-my-pi group/sub-coder
      Multi-role subscription-only YAML templates are staged under:
        #{opt_pkgshare}/examples/subscription-only

      This formula does not modify any live agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    assert_match version.to_s, shell_output("#{bin}/omp --version")

    assert_match "brew upgrade artagon/aitools/omp",
                 shell_output("#{bin}/omp update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/omp",
                 shell_output("#{bin}/omp update --check 2>&1", 2)
    assert_match "subscription-only mode",
                 shell_output("#{bin}/omp --api-key sk-test 2>&1", 2)
    assert_match "subscription-only mode",
                 shell_output("#{bin}/omp auth-broker migrate --from-local --include-env 2>&1", 2)

    assert_path_exists prefix/"LICENSE"
    assert_path_exists pkgshare/"examples/subscription-only/models.yml"
    assert_path_exists pkgshare/"examples/subscription-only/config.yml"
  end
end
