class Hyperfine < Formula
  desc "Command-line benchmarking tool"
  homepage "https://github.com/sharkdp/hyperfine"
  url "https://github.com/sharkdp/hyperfine/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "f4b71df3c78e4cf752ca6fb6ebc4b025f7ea6a5ca5c48fea75f8a1fdb4c7d721"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/sharkdp/hyperfine.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/hyperfine-2.0.0"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "7dbe2979e8d01c3099ea6bedc9f4173bf4c7e44103106e534d0b8e919173a516"
    sha256 cellar: :any,                 arm64_linux:  "8020f6b085723bfb80eda88bea78b5a25f36fbc3e060246083f7068e0195e2ca"
    sha256 cellar: :any,                 x86_64_linux: "d4a17a730dd19672157408fbadeac0f5a2534434989def0ab5e2ae14bad8c06f"
  end

  depends_on "rust" => :build

  def install
    completions = buildpath/"completions"
    ENV["SHELL_COMPLETIONS_DIR"] = completions.to_s

    system "cargo", "install", *std_cargo_args
    man1.install "doc/hyperfine.1"
    bash_completion.install completions/"hyperfine.bash" => "hyperfine"
    zsh_completion.install completions/"_hyperfine"
    fish_completion.install completions/"hyperfine.fish"
    pwsh_completion.install completions/"_hyperfine.ps1"
  end

  def caveats
    <<~EOS
      Homebrew core also provides a `hyperfine` formula. Use the tap-qualified
      name to install or upgrade this tap's build:
        brew install artagon/aitools/hyperfine
        brew upgrade artagon/aitools/hyperfine
    EOS
  end

  test do
    assert_match "hyperfine #{version}", shell_output("#{bin}/hyperfine --version")
    assert_path_exists man1/"hyperfine.1"
    assert_path_exists bash_completion/"hyperfine"
    assert_path_exists zsh_completion/"_hyperfine"
    assert_path_exists fish_completion/"hyperfine.fish"
    assert_path_exists pwsh_completion/"_hyperfine.ps1"

    output = testpath/"benchmark.json"
    system bin/"hyperfine", "--runs", "2", "--export-json", output, "true"
    assert_path_exists output

    report = JSON.parse(output.read)
    assert_equal 2, report["schema_version"]
    assert_equal version.to_s, report.dig("metadata", "hyperfine_version")
    result = report.fetch("results").first
    assert_equal "true", result["command"]
    assert_equal 2, result.fetch("measurements").length
    assert_equal 2, result.dig("summary", "time_wall_clock", "count")
  end
end
