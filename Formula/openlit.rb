class Openlit < Formula
  desc "OpenTelemetry collector CLI for AI coding agents"
  homepage "https://github.com/openlit/openlit"
  url "https://github.com/openlit/openlit/archive/refs/tags/openlit-2.2.0.tar.gz"
  sha256 "0405416faa140979f65062706dedd36eae6832e4a8477ce9ab8340c3bd721620"
  license "Apache-2.0"
  head "https://github.com/openlit/openlit.git", branch: "main"

  livecheck do
    url :stable
    regex(/^openlit[._-]v?(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/openlit-2.2.0"
    rebuild 2
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "d0f3320e21a0726acbbb0d07325ae9f1d334c8860ed9424532f723cbfec4428f"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "d5120472ffce46eec0f0c3ce486fc2d950ef936577a84e241e2c50cc25c86f6b"
    sha256 cellar: :any,                 x86_64_linux: "2e5fa7fd322c6ebc0e16b273e1d160a3a202f545bb7457244970a16a5c3fcf9d"
  end

  depends_on "go" => :build

  def install
    ldflags = "-s -w -X github.com/openlit/openlit/cli/internal/version.Version=#{version}"
    cd "cli" do
      system "go", "build", *std_go_args(ldflags:), "./cmd/openlit"
    end

    generate_completions_from_executable(bin/"openlit", "completion")
    pkgshare.install "plugins", "agent-guides"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/openlit

      `openlit` defaults to loopback OTLP HTTP (`http://127.0.0.1:4318`) and stores
      persistent settings in `~/.config/openlit/config.env` (`openlit configure`).
      To omit prompt and tool bodies from emitted spans, configure:
        openlit configure --content-capture metadata_only

      Coding-agent hook installation is opt-in (`claude-code`, `codex`, `cursor`, `opencode`):
        openlit coding install --vendor=claude-code --dry-run

      Bundled vendor plugin manifests and agent guides are installed under:
        #{opt_pkgshare}/plugins
        #{opt_pkgshare}/agent-guides

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    assert_match "openlit #{version}", shell_output("#{bin}/openlit version")

    show_out = shell_output("#{bin}/openlit configure --show")
    assert_match "http://127.0.0.1:4318", show_out

    system bin/"openlit", "configure",
           "--endpoint", "http://127.0.0.1:4318",
           "--content-capture", "metadata_only"
    cfg_file = testpath/".config/openlit/config.env"
    assert_path_exists cfg_file
    assert_match "OPENLIT_CODING_CONTENT_CAPTURE=metadata_only", cfg_file.read

    dry_out = shell_output("#{bin}/openlit coding install --vendor=claude-code --dry-run")
    assert_match ".claude/plugins/openlit-cc", dry_out
    refute_path_exists testpath/".claude"

    assert_path_exists pkgshare/"plugins/claude-code"
    assert_path_exists pkgshare/"plugins/codex"
  end
end
