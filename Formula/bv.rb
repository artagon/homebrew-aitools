class Bv < Formula
  desc "Graph-aware terminal viewer and triage engine for Beads projects"
  homepage "https://github.com/Dicklesworthstone/beads_viewer"
  # MIT License with OpenAI/Anthropic Rider; full text installed to prefix/LICENSE.
  license :cannot_represent

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/bv-0.27.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "196bcbe461fe47862144f65bcdb930e03413e8ec62cb39ca8f11a9d8ab76294e"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "6822e2627419957d1344a4786404f9ed3e0470000afbe8b11bc9ab5e65c7e5ec"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "bd3f2bc52adc67f97a2e891985299bea502a9a92eb31bb4e436d94f0c554cd01"
  end

  on_macos do
    on_arm do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.27.0/bv_0.27.0_darwin_arm64.tar.gz"
      sha256 "20aa4711c23819aa15c15a333c88e1e6716c23551e080e8020c042389383b28f"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.27.0/bv_0.27.0_darwin_amd64.tar.gz"
      sha256 "4a687c9776ee371a4e2d0b201b7a2523acaa1895ce10f0858c33b02fe7a91452"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.27.0/bv_0.27.0_linux_arm64.tar.gz"
      sha256 "13d7f926a059e74213e0129a3bfdbf2a0a6753febb4fbad8925e63ef43f7ec47"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.27.0/bv_0.27.0_linux_amd64.tar.gz"
      sha256 "7a8f640c95cf73586e1bd6af1d6c9b782ff9768fc07ae8b5cea55adceb817bd7"
    end
  end

  conflicts_with "beads_viewer", because: "both install `bv` binaries"

  def install
    bin.install "bv"
    doc.install "README.md"
    prefix.install "LICENSE"
    generate_completions_from_executable(bin/"bv", shell_parameter_format: :cobra)
  end

  def caveats
    <<~EOS
      Homebrew manages this installation. Do not run `bv --update`; upgrade with:
        brew upgrade artagon/aitools/bv
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s

    assert_match "v#{version}", shell_output("#{bin}/bv --version")
    assert_match "failed to read beads directory",
                 shell_output("#{bin}/bv --robot-insights 2>&1", 1)

    (testpath/".beads/issues.jsonl").write <<~JSON
      {"id":"bv-1","title":"Verify Homebrew triage","status":"open","priority":1,"issue_type":"task","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
    JSON
    assert_match "Verify Homebrew triage", shell_output("#{bin}/bv --robot-triage")
    assert_path_exists prefix/"LICENSE"
  end
end
