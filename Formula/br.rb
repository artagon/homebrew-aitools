class Br < Formula
  desc "Local-first issue tracker for AI coding agents"
  homepage "https://github.com/Dicklesworthstone/beads_rust"
  # MIT License with OpenAI/Anthropic Rider; full text installed to prefix/LICENSE.
  license :cannot_represent
  revision 1

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
    libexec.install "br"
    chmod 0755, libexec/"br"

    (bin/"br").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      skip_next=0
      for arg in "$@"; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        case "${arg}" in
          -- | -h | --help | -V | --version)
            break
            ;;
          --db | --actor | --format | --lock-timeout)
            skip_next=1
            ;;
          --*=* | -*)
            ;;
          upgrade)
            echo "br: in-place self-update is disabled; run: brew upgrade artagon/aitools/br" >&2
            exit 2
            ;;
          *)
            break
            ;;
        esac
      done

      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

      exec "#{libexec}/br" "$@"
    SH
    chmod 0755, bin/"br"

    doc.install "README.md"
    prefix.install "LICENSE"
    generate_completions_from_executable(libexec/"br", "completions")
  end

  def caveats
    <<~EOS
      Homebrew manages this installation. The `br` wrapper blocks `br upgrade`
      (exiting `2`); upgrade with:
        brew upgrade artagon/aitools/br

      This formula does not modify any agent configuration files.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    assert_match "br #{version}", shell_output("#{bin}/br --version")
    assert_match "brew upgrade artagon/aitools/br", shell_output("#{bin}/br upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/br",
                 shell_output("#{bin}/br --actor tester --lock-timeout 5000 upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/br",
                 shell_output("#{bin}/br --db #{testpath}/x.db --format json upgrade 2>&1", 2)
    assert_match "upgrade", shell_output("#{bin}/br help upgrade")

    system bin/"br", "init", "--prefix", "test"
    system bin/"br", "create", "Verify Homebrew formula"
    assert_match "Verify Homebrew formula", shell_output("#{bin}/br list --json")
    assert_path_exists prefix/"LICENSE"
    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
