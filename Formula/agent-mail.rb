class AgentMail < Formula
  desc "Asynchronous coordination MCP server and CLI for AI coding agents"
  homepage "https://github.com/Dicklesworthstone/mcp_agent_mail_rust"
  # MIT License with OpenAI/Anthropic Rider; full text installed to prefix/LICENSE.
  license :cannot_represent

  livecheck do
    url :homepage
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/agent-mail-0.3.41"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "6473e005db9dc41f9fba49de6774d2e970ceac14444580f837a32f1974f9d194"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "d1837e257efca7f3a655902ae16f589a3cc6baaad61009daba1a78ca34030810"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "885a0c7bcf5db4a47577993b4ba4aa6b0905399fb031d4e658fd7e1f9953a802"
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
