class Bd < Formula
  desc "Git-backed graph issue tracker for AI coding agents"
  homepage "https://github.com/gastownhall/beads"
  license "MIT"
  revision 2

  livecheck do
    url :stable
    strategy :github_latest
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
    # Disable bd usage metrics, detached event flushing, and embedded Dolt gRPC
    # metrics during completion generation and at runtime.
    ENV["BD_DISABLE_METRICS"] = "1"
    ENV["BD_DISABLE_EVENT_FLUSH"] = "1"
    ENV["DOLT_METRICS_DISABLED"] = "1"
    ENV["DO_NOT_TRACK"] = "1"

    libexec.install "bd"
    chmod 0755, libexec/"bd"
    (bin/"bd").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export BD_DISABLE_METRICS=1
      export BD_DISABLE_EVENT_FLUSH=1
      export DOLT_METRICS_DISABLED=1
      export DO_NOT_TRACK=1

      exec "#{libexec}/bd" "$@"
    SH
    chmod 0755, bin/"bd"

    doc.install "README.md"
    prefix.install "LICENSE"
    generate_completions_from_executable(libexec/"bd", "completion")
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/bd

      The `bd` wrapper unconditionally enforces:
        BD_DISABLE_METRICS=1
        BD_DISABLE_EVENT_FLUSH=1
        DOLT_METRICS_DISABLED=1
        DO_NOT_TRACK=1
      suppressing anonymous usage metrics, detached `bd send-metrics` flushing,
      and embedded Dolt gRPC metrics while preserving `bd update` and `bd upgrade`.

      `bd init` writes AGENTS.md and agent setup files in the project unless you
      pass --skip-agents. Installing this formula modifies no agent configuration.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    # First verify all four effective child env vars are forced to 1 BEFORE the
    # fixture's first embedded-Dolt database operation.
    probe_src = (bin/"bd").read
    refute_nil probe_src.sub!(%Q(exec "#{libexec}/bd" "$@"), "exec /usr/bin/env")
    probe = testpath/"bd-env-probe"
    probe.write(probe_src)
    chmod 0755, probe

    override_env = {
      "BD_DISABLE_EVENT_FLUSH" => "0",
      "DOLT_METRICS_DISABLED"  => "0",
      "BD_DISABLE_METRICS"     => "0",
      "DO_NOT_TRACK"           => "0",
    }
    override_prefix = override_env.map { |k, v| "#{k}=#{v}" }.join(" ")

    child_env = shell_output("#{override_prefix} #{probe}")
    assert_match(/^BD_DISABLE_METRICS=1$/, child_env)
    assert_match(/^BD_DISABLE_EVENT_FLUSH=1$/, child_env)
    assert_match(/^DOLT_METRICS_DISABLED=1$/, child_env)
    assert_match(/^DO_NOT_TRACK=1$/, child_env)

    assert_match "Anonymous usage metrics: OFF", shell_output("#{override_prefix} #{bin}/bd metrics")
    assert_match "bd version #{version}", shell_output("#{override_prefix} #{bin}/bd --version")

    # Seed a due metrics backlog under $HOME/.beads/eventsData and verify that
    # invoking wrapped bd under explicit *=0 overrides never touches .last-flush
    # or spawns a detached `bd send-metrics` flusher.
    events_dir = testpath/".beads/eventsData"
    events_dir.mkpath
    due_batch = events_dir/"due-test.evtq"
    due_batch.write("{}\n")
    flush_marker = events_dir/".last-flush"
    refute_path_exists flush_marker

    repo = testpath/"repo"
    repo.mkpath
    cd repo do
      system(override_env, bin/"bd", "init", "--prefix", "brewtest",
             "--non-interactive", "--skip-hooks", "--skip-agents", "--quiet")
      assert_path_exists repo/".beads/config.yaml"

      issue = JSON.parse(shell_output("#{override_prefix} #{bin}/bd create 'Brew formula test' --json"))
      assert_equal "Brew formula test", issue["title"]
      issues = JSON.parse(shell_output("#{override_prefix} #{bin}/bd list --json"))
      assert_equal [issue["id"]], issues.map { |entry| entry["id"] }
    end

    refute_path_exists flush_marker
    assert_path_exists due_batch
    assert_path_exists prefix/"LICENSE"
    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
