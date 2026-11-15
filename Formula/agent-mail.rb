class AgentMail < Formula
  desc "Asynchronous coordination MCP server and CLI for AI coding agents"
  homepage "https://github.com/Dicklesworthstone/mcp_agent_mail_rust"
  # MIT License with OpenAI/Anthropic Rider; full text installed to prefix/LICENSE.
  license :cannot_represent

  livecheck do
    url :homepage
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.40/mcp-agent-mail-aarch64-apple-darwin.tar.xz"
      sha256 "9b410ac2ee38e25754efdf246cec69ea46ab9b88ea73aac01267ad38bf73a066"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.40/mcp-agent-mail-x86_64-apple-darwin.tar.xz"
      sha256 "62a869ddde88adb51c7b65bb8185095a8a5bf01d097c66d30d0f327e0a8247dd"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.40/mcp-agent-mail-aarch64-unknown-linux-gnu.tar.xz"
      sha256 "f8381f01927805427b8f9f40b9033c7e4a2a68853b22bc258035a2b6392b9780"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.40/mcp-agent-mail-x86_64-unknown-linux-musl.tar.xz"
      sha256 "cd7784066ced9e53f52d20cd5785f5c785c05cd5a2d214a3165348eb67703c56"
    end
  end

  def install
    bin.install "mcp-agent-mail", "am"
    doc.install "README.md"
    prefix.install "LICENSE"
  end

  def caveats
    <<~EOS
      Homebrew manages this installation. Do not run `am self-update`; upgrade with:
        brew upgrade artagon/aitools/agent-mail

      To run the local HTTP MCP server:
        #{opt_bin}/am serve-http

      To register the stdio MCP server, use the stable opt path:
        #{opt_bin}/mcp-agent-mail

      This formula does not modify any agent configuration files.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s

    assert_match "mcp-agent-mail #{version}", shell_output("#{bin}/mcp-agent-mail --version")
    assert_match "am #{version}", shell_output("#{bin}/am --version")
    assert_match "am.capabilities.v1", shell_output("#{bin}/am capabilities")
    assert_path_exists prefix/"LICENSE"
  end
end
