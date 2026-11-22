class Openlit < Formula
  desc "OpenTelemetry collector CLI for AI coding agents"
  homepage "https://github.com/openlit/openlit"
  url "https://github.com/openlit/openlit/archive/refs/tags/openlit-2.1.1.tar.gz"
  sha256 "9aee93e79be0a7a13db13bfd099cb9d893f0118ade943d19d245f34c9036da9c"
  license "Apache-2.0"
  head "https://github.com/openlit/openlit.git", branch: "main"

  livecheck do
    url :stable
    regex(/^openlit[._-]v?(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
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
