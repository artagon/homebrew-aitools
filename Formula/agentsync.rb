class Agentsync < Formula
  desc "Sync AI agent configurations and MCP servers via symbolic links"
  homepage "https://github.com/dallay/agentsync"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/agentsync-1.53.1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "a7ac20920d6d1edbdb7d93d91db75f9fe113c285cf393309eb5fbd78d017de37"
  end

  on_macos do
    on_arm do
      url "https://github.com/dallay/agentsync/releases/download/v1.53.1/agentsync-1.53.1-aarch64-apple-darwin.tar.gz"
      sha256 "d7f0e0fefda5748878a7aa2c10ead81eaccbb4afe5d5f9f961360b4b976eb97f"
    end
    on_intel do
      url "https://github.com/dallay/agentsync/releases/download/v1.53.1/agentsync-1.53.1-x86_64-apple-darwin.tar.gz"
      sha256 "a8557311a84e32f90a2988419af47dc2e02ab5914291a1db633c869bb83697ae"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/dallay/agentsync/releases/download/v1.53.1/agentsync-1.53.1-aarch64-unknown-linux-musl.tar.gz"
      sha256 "202ebd9b4cb578fa3584f83e7b384a59c92f8dab907da893aeabad2caf16234a"
    end
    on_intel do
      url "https://github.com/dallay/agentsync/releases/download/v1.53.1/agentsync-1.53.1-x86_64-unknown-linux-musl.tar.gz"
      sha256 "74b6c3c669b731787298bd0651f299e097292d9cc94a80a23665d52279b9fd8d"
    end
  end

  def install
    libexec.install "agentsync"
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
