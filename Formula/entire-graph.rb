class EntireGraph < Formula
  desc "Deterministic local code graph for coding agents"
  homepage "https://github.com/entireio/entire-graph"
  url "https://github.com/entireio/entire-graph/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "112137cac1dcb883cc35146500c062a584b315b57d2e4e4394b957f7ee2ae579"
  license "MIT"
  head "https://github.com/entireio/entire-graph.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    # Allow opt-in Claude prompt-context hook usage with standalone `entire-graph`
    # when `entire-cli` (`entire`) is not installed alongside it.
    inreplace "scripts/entire-graph-prompt-context.py",
              [
                '    entire = safe_path_executable("entire", env)',
                '    return [entire, "graph"] if entire else None',
              ].join("\n"),
              [
                '    entire = safe_path_executable("entire", env)',
                "    if entire:",
                '        return [entire, "graph"]',
                '    standalone = safe_path_executable("entire-graph", env)',
                "    return [standalone] if standalone else None",
              ].join("\n")

    ENV["CGO_ENABLED"] = "1"
    ldflags = "-s -w -X main.version=v#{version}"
    system "go", "build", *std_go_args(output: libexec/"entire-graph", ldflags:), "./cmd/entire-graph"
    libexec.install "entire-plugin.yml"
    bin.install_symlink libexec/"entire-graph"

    prefix.install "NOTICES"

    pkgshare.install ".claude-plugin", "entire-plugin.yml", "hooks"
    (pkgshare/"skills").install "skills/stats"
    (pkgshare/"scripts").install "scripts/entire-graph-prompt-context.py",
                                 "scripts/entire-graph-statusline.sh"
    chmod 0755, [
      pkgshare/"scripts/entire-graph-prompt-context.py",
      pkgshare/"scripts/entire-graph-statusline.sh",
    ]
    pkgshare.install_symlink bin/"entire-graph"
  end

  def caveats
    <<~EOS
      Run standalone against any Git repository (`git` 2.36+):
        entire-graph query --repo . --profile full --head --format agent --query "<task>"
        entire-graph impact --repo . --head --symbol <Name>

      If `entire-cli` is installed, register the `entire graph` plugin from:
        #{opt_libexec}/entire-graph

      Bundled agent skills, opt-in Claude Code hooks, and statusline scripts
      are staged passively under:
        #{opt_pkgshare}/skills
        #{opt_pkgshare}/hooks
        #{opt_pkgshare}/scripts

      Upgrade with:
        brew upgrade artagon/aitools/entire-graph

      Installing or upgrading this formula never modifies agent or repository
      configuration files (`entire-graph setup --repo .` is strictly opt-in).
    EOS
  end

  test do
    home = testpath/"home"
    home.mkpath
    ENV["HOME"] = home.to_s
    ENV["XDG_CACHE_HOME"] = (testpath/"cache").to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s
    ENV["GIT_CONFIG_GLOBAL"] = File::NULL
    ENV["GIT_CONFIG_SYSTEM"] = File::NULL

    assert_equal "v#{version}", shell_output("#{bin}/entire-graph version").strip

    doctor = JSON.parse(shell_output("#{bin}/entire-graph doctor --json"))
    assert_equal "entire-graph", doctor["provider"]
    assert_equal "v#{version}", doctor["version"]
    assert doctor["no_egress"]
    refute doctor.dig("phase_1_local_only", "upload_telemetry")

    caps = JSON.parse(shell_output("#{bin}/entire-graph capabilities --json"))
    assert_includes caps.fetch("semantic_languages"), "Go"
    refute caps.dig("features_requiring_network_access", "telemetry_upload")

    repo = testpath/"repo"
    repo.mkpath
    (repo/"go.mod").write <<~EOS
      module example.com/demo

      go 1.24
    EOS
    (repo/"billing.go").write <<~GO
      package demo

      func ComputeInvoiceTotal(subtotal int, tax int) int {
      \treturn subtotal + tax
      }
    GO
    (repo/"checkout.go").write <<~GO
      package demo

      func FinalizeOrder(subtotal int) int {
      \treturn ComputeInvoiceTotal(subtotal, 5)
      }
    GO

    system "git", "-C", repo, "init", "-q", "-b", "main"
    system "git", "-C", repo, "add", "."
    system "git", "-C", repo, "-c", "user.name=Brew Test", "-c", "user.email=test@example.com",
           "commit", "-q", "-m", "initial"

    health = JSON.parse(shell_output("#{bin}/entire-graph health --repo #{repo} --json"))
    assert_equal "ok", health.dig("completeness", "health", "status")
    assert_equal 2, health.dig("counts", "symbols")

    query_out = shell_output(
      "#{bin}/entire-graph query --repo #{repo} --profile full --head --format agent --query 'compute invoice total'",
    )
    assert_match "billing.go:3-5 ComputeInvoiceTotal", query_out

    impact_out = shell_output("#{bin}/entire-graph impact --repo #{repo} --head --symbol ComputeInvoiceTotal")
    assert_match "FinalizeOrder (checkout.go:4)", impact_out

    assert_path_exists prefix/"NOTICES"
    assert_path_exists libexec/"entire-plugin.yml"
    assert_path_exists pkgshare/"skills/stats/SKILL.md"
    assert_path_exists pkgshare/"hooks/hooks.json"
    assert_path_exists pkgshare/".claude-plugin/plugin.json"
    assert_predicate pkgshare/"scripts/entire-graph-prompt-context.py", :executable?
    assert_predicate pkgshare/"scripts/entire-graph-statusline.sh", :executable?
    refute_path_exists home/".claude"
    refute_path_exists home/".codex"
    refute_path_exists home/".gemini"
    refute_path_exists home/".agents"
  end
end
