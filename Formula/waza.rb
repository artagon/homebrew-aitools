class Waza < Formula
  desc "Evaluate and benchmark AI agent workflows, custom agents, and skills"
  homepage "https://microsoft.github.io/waza/"
  url "https://github.com/microsoft/waza/archive/refs/tags/v0.41.0.tar.gz"
  sha256 "b149312962adbc0711d900d295417f60e450acb153ea3eb8d150dd1287aa8a39"
  license "MIT"
  head "https://github.com/microsoft/waza.git", branch: "main"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  depends_on "go" => :build
  depends_on "node" => :build

  def install
    ENV["PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD"] = "1"
    cd "web" do
      system "npm", "ci", "--ignore-scripts"
      system "npm", "run", "build"
    end

    ldflags = "-s -w -X main.version=#{version}"
    system "go", "build", *std_go_args(output: libexec/"waza", ldflags:), "./cmd/waza"
    generate_completions_from_executable(libexec/"waza", "completion")

    (pkgshare/"skills").install "skills/waza", "skills/waza-interactive"

    (bin/"waza").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export WAZA_NO_UPDATE_CHECK="${WAZA_NO_UPDATE_CHECK:-1}"

      seen_subcmd=0
      for arg in "$@"; do
        case "${arg}" in
          --)
            break
            ;;
          -*)
            ;;
          *)
            if [[ "${seen_subcmd}" -eq 0 ]]; then
              seen_subcmd=1
              if [[ "${arg}" = "update" ]]; then
                printf '%s\\n' "Error: Homebrew manages waza upgrades. Run: brew upgrade artagon/aitools/waza" >&2
                exit 2
              fi
            fi
            ;;
        esac
      done

      exec "#{libexec}/waza" "$@"
    SH
    chmod 0755, bin/"waza"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `waza update`. Use:
        brew upgrade artagon/aitools/waza

      Startup update checks are disabled by default (`WAZA_NO_UPDATE_CHECK=1`).

      Bundled agent skills are installed under:
        #{opt_pkgshare}/skills

      This formula does not modify any agent configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match version.to_s, shell_output("#{bin}/waza --version")
    assert_match "brew upgrade artagon/aitools/waza", shell_output("#{bin}/waza update 2>&1", 2)

    proj = testpath/"eval-demo"
    proj.mkpath
    # Pipe empty stdin so waza init runs non-interactively under Homebrew's test PTY.
    pipe_output("#{bin}/waza init --no-skill #{proj}", "", 0)
    assert_path_exists proj/".waza.yaml"
    assert_path_exists proj/"skills"
    assert_path_exists proj/"evals"
    assert_path_exists pkgshare/"skills/waza/SKILL.md"
    assert_path_exists pkgshare/"skills/waza-interactive/SKILL.md"
  end
end
