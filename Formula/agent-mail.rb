class AgentMail < Formula
  desc "Asynchronous coordination MCP server and CLI for AI coding agents"
  homepage "https://github.com/Dicklesworthstone/mcp_agent_mail_rust"
  # MIT License with OpenAI/Anthropic Rider; full text installed to prefix/LICENSE.
  license :cannot_represent
  revision 1

  livecheck do
    url :homepage
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.41/mcp-agent-mail-aarch64-apple-darwin.tar.xz"
      sha256 "1fa85ffa1578b5979d250f2ef3ae4b2fc6ae730cd50c84815755edd87b81ad4d"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.41/mcp-agent-mail-x86_64-apple-darwin.tar.xz"
      sha256 "0743ca92e0a1ee938bed7d750fc7516ab4323a51ee0fb511881dcce01fc93c4a"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.41/mcp-agent-mail-aarch64-unknown-linux-gnu.tar.xz"
      sha256 "5e0106db798433e153eb28e4abca16dcebcdb998e6069ba87b6fa2aa5d7c9d93"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.41/mcp-agent-mail-x86_64-unknown-linux-musl.tar.xz"
      sha256 "30b3866304b26d14428ce0f85d34e422aca699519f1196ec2f58fbdcdb9e7ccd"
    end
  end

  def install
    libexec.install "mcp-agent-mail", "am"
    chmod 0755, [libexec/"mcp-agent-mail", libexec/"am"]

    %w[am mcp-agent-mail].each do |entry|
      (bin/entry).write <<~SH
        #!/bin/bash
        # Target contract: macOS /bin/bash 3.2+ wrapper.
        set -euo pipefail

        for arg in "$@"; do
          case "${arg}" in
            -- | -h | --help | -V | --version)
              break
              ;;
            self-update | update)
              echo "agent-mail: in-place self-update is disabled; run: brew upgrade artagon/aitools/agent-mail" >&2
              exit 2
              ;;
            -*)
              ;;
            *)
              break
              ;;
          esac
        done

        export HTTP_HOST="${HTTP_HOST:-127.0.0.1}"
        export CONVERT_IMAGES="${CONVERT_IMAGES:-false}"
        export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

        exec "#{libexec}/#{entry}" "$@"
      SH
      chmod 0755, bin/entry
    end

    (pkgshare/"skills/agent-mail/SKILL.md").write <<~EOS
      ---
      name: agent-mail
      description: Coordinate multiple AI coding agents over local Agent Mail MCP and CLI (v0.3.x) using threads, inboxes, file reservations, and local HTTP or stdio servers. Use when registering agents, messaging peers, reserving paths, or operating local Agent Mail services.
      ---

      # Agent Mail Multi-Agent Coordination (`am` / `mcp-agent-mail`)

      ## Server & CLI Entrypoints

      - Local HTTP MCP server (defaults to `127.0.0.1`):
        `am serve-http --no-tui`
      - Direct stdio MCP server:
        `mcp-agent-mail`
      - CLI capability discovery:
        `am capabilities --format json`
      - Legacy import / data migration helper (distinct from binary upgrades):
        `am upgrade`

      ## Coordination Workflow

      1. Register each agent once per project and inspect unread mail before editing shared files.
      2. Reserve target file globs with an explicit TTL before modifying contested paths; release reservations promptly when done.
      3. Keep messages concise, thread-scoped, and explicit about affected file paths and verification results.

      ## Tap Hardening Notes

      - Both `am` and `mcp-agent-mail` default `HTTP_HOST=127.0.0.1`, `CONVERT_IMAGES=false`, and `DO_NOT_TRACK=1`.
      - In-place self-updates (`am self-update`, `am update`, `AM_INTERFACE_MODE=cli mcp-agent-mail self-update`) exit `2`; upgrade via `brew upgrade artagon/aitools/agent-mail`.
    EOS

    doc.install "README.md"
    prefix.install "LICENSE"
  end

  def caveats
    <<~EOS
      Homebrew manages this installation. Both `am` and `mcp-agent-mail` block
      in-place self-updates (`self-update` and `update`, exiting `2`); upgrade with:
        brew upgrade artagon/aitools/agent-mail

      Wrappers default `HTTP_HOST=127.0.0.1`, `CONVERT_IMAGES=false`, and
      `DO_NOT_TRACK=1` while preserving `am upgrade` and server modes.

      To run the local HTTP MCP server:
        #{opt_bin}/am serve-http

      To register the stdio MCP server, use the stable opt path:
        #{opt_bin}/mcp-agent-mail

      A companion agent skill is staged passively under:
        #{opt_pkgshare}/skills/agent-mail

      This formula does not modify any agent configuration files.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    assert_match "mcp-agent-mail #{version}", shell_output("#{bin}/mcp-agent-mail --version")
    assert_match "am #{version}", shell_output("#{bin}/am --version")
    assert_match "am.capabilities.v1", shell_output("#{bin}/am capabilities")

    %w[am mcp-agent-mail].each do |entry|
      probe_src = (bin/entry).read
      refute_nil probe_src.sub!(%Q(exec "#{libexec}/#{entry}" "$@"), "exec /usr/bin/env")
      probe = testpath/"#{entry}-env-probe"
      probe.write(probe_src)
      chmod 0755, probe

      env_out = shell_output("env -u HTTP_HOST -u CONVERT_IMAGES -u DO_NOT_TRACK #{probe} -- --self-update")
      assert_match(/^HTTP_HOST=127\.0\.0\.1$/, env_out)
      assert_match(/^CONVERT_IMAGES=false$/, env_out)
      assert_match(/^DO_NOT_TRACK=1$/, env_out)
    end

    assert_match "brew upgrade artagon/aitools/agent-mail", shell_output("#{bin}/am self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-mail", shell_output("#{bin}/am update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-mail", shell_output("#{bin}/am -v self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-mail",
                 shell_output("AM_INTERFACE_MODE=cli #{bin}/mcp-agent-mail self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agent-mail",
                 shell_output("AM_INTERFACE_MODE=cli #{bin}/mcp-agent-mail update 2>&1", 2)

    assert_match "self-update", shell_output("#{bin}/am help self-update")
    assert_match "upgrade", shell_output("#{bin}/am help upgrade")
    assert_path_exists pkgshare/"skills/agent-mail/SKILL.md"
    assert_path_exists prefix/"LICENSE"
    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".claude.json"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
