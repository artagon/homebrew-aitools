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
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/openlit-2.1.1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "1b667ea986eabdd290e2320c52370f1785bd81616446fa3eefa3310ee5d17da7"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "bd0c414d2adc57d1c3299fdfd949b508d0d3b3388fd79371acf3eec844e57331"
    sha256 cellar: :any,                 x86_64_linux: "00ff45f2a5f2add82247d3e31db8584a4a53aa98d3db50756e5238abb8e00339"
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
