class Bv < Formula
  desc "Graph-aware terminal viewer and triage engine for Beads projects"
  homepage "https://github.com/Dicklesworthstone/beads_viewer"
  # MIT License with OpenAI/Anthropic Rider; full text installed to prefix/LICENSE.
  license :cannot_represent

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.26.0/bv_0.26.0_darwin_arm64.tar.gz"
      sha256 "3090ef0001a7d7c01dbc7882e53075f9a8b832b26659483e12d60f6e672ab2aa"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.26.0/bv_0.26.0_darwin_amd64.tar.gz"
      sha256 "d6f68017e6f52c33125ece36eb7e87991b1fda20b614d198129fe6b5c274d5c3"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.26.0/bv_0.26.0_linux_arm64.tar.gz"
      sha256 "1fa1c8234a4db6ad6c930ef8bfd8819784041ddb206c232d3103bd2f2a3f8a3f"
    end
    on_intel do
      url "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v0.26.0/bv_0.26.0_linux_amd64.tar.gz"
      sha256 "e9f52cda29bb074b166e7c89a3af075fa506e29734085bc4b55348b8a4aab4f1"
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
