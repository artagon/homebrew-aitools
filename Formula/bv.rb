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
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.29.0/bv_0.29.0_darwin_arm64.tar.gz"
      sha256 "37247943aad516cf667add30c940034673f1e53f8ae024d3b23c6c8dc6265fb0"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.29.0/bv_0.29.0_darwin_amd64.tar.gz"
      sha256 "f0dfe04723de94fc6eeec8aec17f805217ffff9b1b56c02bedfd67bb6ccbaddd"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.29.0/bv_0.29.0_linux_arm64.tar.gz"
      sha256 "3a58d739f42d1d6ee446afece7376d795190d7c2cd9414a357563a7b62fb57b9"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.29.0/bv_0.29.0_linux_amd64.tar.gz"
      sha256 "772ec0d327a64fe461cf04f140e65df132da3b79d28285e581619685a7ea1888"
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
