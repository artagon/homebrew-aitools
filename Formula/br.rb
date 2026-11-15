class Br < Formula
  desc "Local-first issue tracker for AI coding agents"
  homepage "https://github.com/Dicklesworthstone/beads_rust"
  # MIT License with OpenAI/Anthropic Rider; full text installed to prefix/LICENSE.
  license :cannot_represent

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/Dicklesworthstone/beads_rust/releases/download/v0.7.6/br-0.7.6-darwin_arm64.tar.gz"
      sha256 "d01a4ef66aa5cd40152fc6481b78def7b6dfefd56da1b26dd1c84b38603de6f6"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/beads_rust/releases/download/v0.7.6/br-0.7.6-darwin_amd64.tar.gz"
      sha256 "7732a5bfa954f559bf0822ada071f32416b8a46e32ad33819c07d5942b29c46e"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Dicklesworthstone/beads_rust/releases/download/v0.7.6/br-0.7.6-linux_musl_arm64.tar.gz"
      sha256 "7b6ea53d1b3b835115074e18bf6794caaf335bbe5b4f45fdb8091a9cf67c633a"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/beads_rust/releases/download/v0.7.6/br-0.7.6-linux_musl_amd64.tar.gz"
      sha256 "28b89f8f26540a4c9e6242b3c9fc93bcdd89f4ec0b9c9792895028c53f5bf2bd"
    end
  end

  def install
    bin.install "br"
    doc.install "README.md"
    prefix.install "LICENSE"
    generate_completions_from_executable(bin/"br", "completions")
  end

  def caveats
    <<~EOS
      Homebrew manages this installation. Do not run `br upgrade`; upgrade with:
        brew upgrade artagon/aitools/br
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s

    assert_match "br #{version}", shell_output("#{bin}/br --version")
    system bin/"br", "init", "--prefix", "test"
    system bin/"br", "create", "Verify Homebrew formula"
    assert_match "Verify Homebrew formula", shell_output("#{bin}/br list --json")
    assert_path_exists prefix/"LICENSE"
  end
end
