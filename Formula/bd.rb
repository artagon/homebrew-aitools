class Bd < Formula
  desc "Git-backed graph issue tracker for AI coding agents"
  homepage "https://github.com/gastownhall/beads"
  license "MIT"
  revision 1

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4_1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "d2dcbe80bd513a3baa4eaf1700c5d826cb8e566fb661fa5d5074571f990eb317"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "c8b8b77fce191460b7183d48a144d2f2cc90d864f9478b01cd4d85579b2cd6e5"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "4640e09db20229d6c281e3ae71bd19dc68c0914f06affaf853e1e17b54bf77ae"
  end

  # Upstream release binaries embed the Dolt engine and link only system libraries.
  on_macos do
    on_arm do
      url "https://github.com/gastownhall/beads/releases/download/v1.3.4/beads_1.3.4_darwin_arm64.tar.gz"
      sha256 "b08a9c15bff80c42235f32946f94a6566a7d90944fe8afe45f3fd2f350596cdb"
    end
    on_intel do
      url "https://github.com/gastownhall/beads/releases/download/v1.3.4/beads_1.3.4_darwin_amd64.tar.gz"
      sha256 "05e713a2da8eeaba40b924184735d9a34d2da8669e4d3ac50cc716605ba10640"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/gastownhall/beads/releases/download/v1.3.4/beads_1.3.4_linux_arm64.tar.gz"
      sha256 "f4ee6eb3ec79bb2d7eb9d717c73efbcb6fa763cc70f726b4d055b72afdd68ad5"
    end
    on_intel do
      url "https://github.com/gastownhall/beads/releases/download/v1.3.4/beads_1.3.4_linux_amd64.tar.gz"
      sha256 "175c26904bde3ff9168d2282ff6b56f17b17f60c22fa5acb3dacc9fb3465303a"
    end
  end

  conflicts_with "beads", because: "both install `bd` binaries"

  def install
    # bd sends anonymous usage metrics by default; disable metrics at build and runtime.
    ENV["BD_DISABLE_METRICS"] = "1"

    libexec.install "bd"
    chmod 0755, libexec/"bd"
    (bin/"bd").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export BD_DISABLE_METRICS="${BD_DISABLE_METRICS:-1}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

      exec "#{libexec}/bd" "$@"
    SH
    chmod 0755, bin/"bd"

    doc.install "README.md"
    prefix.install "LICENSE"
    generate_completions_from_executable(libexec/"bd", "completion")
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/bd

      Anonymous usage metrics are disabled by default in the `bd` wrapper
      (`BD_DISABLE_METRICS=1`, `DO_NOT_TRACK=1`).

      `bd init` writes AGENTS.md and agent setup files in the project unless you
      pass --skip-agents. Installing this formula modifies no agent configuration.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["BD_DISABLE_METRICS"] = "1"

    assert_match "bd version #{version}", shell_output("#{bin}/bd --version")

    # The embedded Dolt engine needs no external server.
    system bin/"bd", "init", "--prefix", "brewtest", "--non-interactive", "--skip-hooks", "--skip-agents", "--quiet"
    assert_path_exists testpath/".beads/config.yaml"

    issue = JSON.parse(shell_output("#{bin}/bd create 'Brew formula test' --json"))
    assert_equal "Brew formula test", issue["title"]
    issues = JSON.parse(shell_output("#{bin}/bd list --json"))
    assert_equal [issue["id"]], issues.map { |entry| entry["id"] }

    assert_path_exists prefix/"LICENSE"
  end
end
