class Agentsync < Formula
  desc "Sync AI agent configurations and MCP servers via symbolic links"
  homepage "https://github.com/dallay/agentsync"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/dallay/agentsync/releases/download/v1.53.2/agentsync-1.53.2-aarch64-apple-darwin.tar.gz"
      sha256 "ef72f00ec7700503e2eae6f4b4d5afe529715af6256c03eec1fe82226c62171a"
    end
    on_intel do
      url "https://github.com/dallay/agentsync/releases/download/v1.53.2/agentsync-1.53.2-x86_64-apple-darwin.tar.gz"
      sha256 "4f4bc261d2948654a089fc5e81d3c4ac4ec078ebfe9916b6965a55c53e278b82"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/dallay/agentsync/releases/download/v1.53.2/agentsync-1.53.2-aarch64-unknown-linux-musl.tar.gz"
      sha256 "e56492dcea3d940382cb108bb3a7199b26b8e931e9ca15e9a2bc418e574d7f8f"
    end
    on_intel do
      url "https://github.com/dallay/agentsync/releases/download/v1.53.2/agentsync-1.53.2-x86_64-unknown-linux-musl.tar.gz"
      sha256 "8de319217cc1797262b59f84a60d661b0621f540d9dab1695a06783717ffa4af"
    end
  end

  def install
    libexec.install "agentsync"
    chmod 0755, libexec/"agentsync"
    (bin/"agentsync").write_env_script libexec/"agentsync", AGENTSYNC_NO_UPDATE_CHECK: "1"
    doc.install "README.md"
    prefix.install "LICENSE"
  end

  def caveats
    <<~EOS
      Automatic upstream update checks are disabled.
      Use Homebrew to upgrade instead of an upstream updater:
        brew upgrade artagon/aitools/agentsync
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s
    assert_match version.to_s, shell_output("#{bin}/agentsync --version")
    system bin/"agentsync", "init"
    assert_path_exists testpath/".agents/agentsync.toml"
    assert_path_exists prefix/"LICENSE"
  end
end
