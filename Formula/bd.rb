class Bd < Formula
  desc "Git-backed graph issue tracker for AI coding agents"
  homepage "https://github.com/gastownhall/beads"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/bd-1.3.4"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "c6f3d9bdcb5041c9ece17e6b11dacbde40b46d5ef86b1199167f47056d9b0235"
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
    # bd sends anonymous usage metrics by default; keep the build from sending any.
    ENV["BD_DISABLE_METRICS"] = "1"

    bin.install "bd"
    doc.install "README.md"
    prefix.install "LICENSE"
    generate_completions_from_executable(bin/"bd", "completion")
  end

  def caveats
    <<~EOS
      bd sends anonymous usage metrics by default. To opt out, run
        bd metrics off
      or set BD_DISABLE_METRICS=1.

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
