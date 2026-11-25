class AgentTincan < Formula
  desc "Tailscale-based relay and MCP bridge for AI agent collaboration"
  homepage "https://agenttincan.com"
  url "https://github.com/mvanhorn/agent-tincan/archive/refs/tags/v0.32.0.tar.gz"
  sha256 "2f78df6b04225f4289c251ab7095830a984fcdd90a83d15e000d57d7b62ce7d7"
  license "MIT"
  head "https://github.com/mvanhorn/agent-tincan.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/agent-tincan-0.32.0"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "65067393df662dce4897b4ceb372b284564466a2a4869d3738bd441cd294245c"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "fe86c54b8eae0044a45abfe4914100672cfae0e52d21b4809dcf28eec1c2fa3d"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "19c9545a307ce0abb2353327c54198e4807e4b8681c1e7ba99df9e705b62cbcc"
  end

  depends_on "go" => :build

  deny_network_access! [:build, :postinstall]

  def fetch
    system "go", "mod", "download"
  end

  def install
    ENV["CGO_ENABLED"] = "0"
    ldflags = "-s -w -X main.Version=#{version}"
    system "go", "build", *std_go_args(output: libexec/"tincan", ldflags:), "./cmd/tincan"
    chmod 0755, libexec/"tincan"

    with_env(HOME: buildpath.to_s, XDG_CONFIG_HOME: (buildpath/".config").to_s) do
      generate_completions_from_executable(libexec/"tincan", "completion", base_name: "tincan")
    end

    # Stage the unpacked Chrome history extension (exact release manifest files)
    # and user/agent setup documentation passively under pkgshare.
    (pkgshare/"extension").install %w[
      extension/manifest.json
      extension/background.js
      extension/ops.js
      extension/send.js
      extension/options.html
      extension/options.js
      extension/icon16.png
      extension/icon48.png
      extension/icon128.png
    ]
    (pkgshare/"docs").install "site/agents.txt",
                              "site/llms.txt",
                              "docs/quickstart.md",
                              "docs/protocol.md",
                              "docs/trust-model.md",
                              "docs/a2a.md",
                              "docs/phone.md",
                              "docs/tasks.md",
                              "docs/adapters"
    (pkgshare/"docs/extension.md").write((buildpath/"extension/README.md").read)

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `agent-tincan` (`artagon/aitools/agent-tincan`)

      - **Binary:** `tincan` (`tincan version` prints version; `tincan mcp` is the stdio MCP server)
      - **Config paths:** `~/.config/tincan/client.json` (`TINCAN_CONFIG`, `TINCAN_RELAY`, `TS_AUTHKEY`)
      - **Hardening:** Wrapper exports `DO_NOT_TRACK=1` and blocks `upgrade`, `relay-upgrade`, and `relay install --self-upgrade` (`exit 2`).
      - **Service installs:** Pass `--binary #{opt_bin}/tincan` so launchd/systemd units survive upgrades.
      - **Passive assets:** `#{opt_pkgshare}/extension` and `#{opt_pkgshare}/docs/agents.txt`
      - **Upgrade:** `brew upgrade artagon/aitools/agent-tincan`
    MARKDOWN

    (bin/"tincan").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

      first_cmd=""
      second_cmd=""
      for arg in "$@"; do
        case "${arg}" in
          --)
            break
            ;;
          -h | --help)
            if [[ -z "${first_cmd}" ]]; then
              break
            fi
            ;;
          --self-upgrade | --self-upgrade=*)
            if [[ "${first_cmd}" = "relay" && "${second_cmd}" = "install" ]]; then
              case "${arg}" in
                --self-upgrade=false | --self-upgrade=0)
                  ;;
                *)
                  printf '%s\\n' "Error: Homebrew manages agent-tincan upgrades. Run: brew upgrade artagon/aitools/agent-tincan" >&2
                  exit 2
                  ;;
              esac
            fi
            ;;
          -*)
            ;;
          *)
            if [[ -z "${first_cmd}" ]]; then
              first_cmd="${arg}"
              case "${arg}" in
                upgrade | relay-upgrade)
                  printf '%s\\n' "Error: Homebrew manages agent-tincan upgrades. Run: brew upgrade artagon/aitools/agent-tincan" >&2
                  exit 2
                  ;;
                *)
                  ;;
              esac
            elif [[ -z "${second_cmd}" ]]; then
              second_cmd="${arg}"
            fi
            ;;
        esac
      done

      exec "#{libexec}/tincan" "$@"
    SH
    chmod 0755, bin/"tincan"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `tincan upgrade`, `tincan relay-upgrade`,
      or `tincan relay install --self-upgrade`. Upgrade with:
        brew upgrade artagon/aitools/agent-tincan

      Register #{opt_bin}/tincan as a stdio MCP server in your agent's MCP config:
        #{opt_bin}/tincan mcp

      When installing background services (`tincan relay install`, `tincan listen install`),
      pass `--binary #{opt_bin}/tincan` so service definitions stay valid across Homebrew
      upgrades. This reproducible source build omits upstream's Developer-ID-signed
      `Agent Tincan.app` Login Items wrapper, so macOS LaunchAgents invoke `tincan` directly.

      The unpacked Chrome history extension, setup guides, and package agent guide are staged passively under:
        #{opt_pkgshare}/extension
        #{opt_pkgshare}/docs/agents.txt
        #{opt_share}/doc/agent-tincan/AGENTS.md

      This formula does not modify any live agent, browser, or service configuration files.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    assert_equal version.to_s, shell_output("#{bin}/tincan version").strip
    help_out = shell_output("#{bin}/tincan --help")
    assert_match "mcp", help_out
    assert_match "relay", help_out

    assert_match "brew upgrade artagon/aitools/agent-tincan",
                 shell_output("#{bin}/tincan upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-tincan",
                 shell_output("#{bin}/tincan upgrade --check 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-tincan",
                 shell_output("#{bin}/tincan relay-upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-tincan",
                 shell_output("#{bin}/tincan relay-upgrade --latest 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-tincan",
                 shell_output("#{bin}/tincan relay install --self-upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-tincan",
                 shell_output("#{bin}/tincan relay install --self-upgrade=true 2>&1", 2)

    assert_match "Usage:", shell_output("#{bin}/tincan -h upgrade")
    assert_match "Download the tincan build", shell_output("#{bin}/tincan help upgrade")
    assert_match "Ask the relay to install", shell_output("#{bin}/tincan help relay-upgrade")
    assert_match "Usage:", shell_output("#{bin}/tincan -- --upgrade")
    assert_match "Usage:", shell_output("#{bin}/tincan -- upgrade")

    onboard_out = shell_output("#{bin}/tincan onboard --offline --section operator")
    assert_match "Operator prompt", onboard_out

    probe_src = (bin/"tincan").read
    refute_nil probe_src.sub!(%Q(exec "#{libexec}/tincan" "$@"), "exec /usr/bin/env")
    probe = testpath/"tincan-env-probe"
    probe.write(probe_src)
    chmod 0755, probe

    default_env = shell_output("env -u DO_NOT_TRACK #{probe} version")
    assert_match(/^DO_NOT_TRACK=1$/, default_env)
    custom_env = shell_output("DO_NOT_TRACK=0 #{probe} version")
    assert_match(/^DO_NOT_TRACK=0$/, custom_env)

    assert_path_exists bash_completion/"tincan"
    assert_path_exists zsh_completion/"_tincan"
    assert_path_exists fish_completion/"tincan.fish"
    assert_path_exists pkgshare/"extension/manifest.json"
    assert_path_exists pkgshare/"docs/agents.txt"
    assert_path_exists pkgshare/"docs/llms.txt"
    assert_path_exists pkgshare/"docs/quickstart.md"
    assert_path_exists pkgshare/"docs/extension.md"
    assert_path_exists doc/"AGENTS.md"

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
