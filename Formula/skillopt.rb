class Skillopt < Formula
  desc "Text-space optimizer and offline sleep consolidation for AI agent skills"
  homepage "https://github.com/microsoft/SkillOpt"
  url "https://github.com/microsoft/SkillOpt/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "56c7a2dba8dd6d2908807b67d26dec1f45d7869f54926d99961da3a0d165d5db"
  license "MIT"
  head "https://github.com/microsoft/SkillOpt.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "uv" => :build

  on_linux do
    depends_on "python@3.13"
  end

  preserve_rpath

  def install
    # Default MCP server working directory to caller cwd when SKILLOPT_SLEEP_REPO
    # is unset, rather than the read-only Homebrew Cellar pkgshare path.
    inreplace "plugins/copilot/mcp_server.py",
              'REPO_ROOT = os.environ.get("SKILLOPT_SLEEP_REPO") or os.path.abspath(',
              'REPO_ROOT = os.environ.get("SKILLOPT_SLEEP_REPO") or os.getcwd() or os.path.abspath('

    python_arg = if OS.mac?
      ENV["UV_PYTHON_PREFERENCE"] = "only-managed"
      ENV["UV_PYTHON_INSTALL_DIR"] = libexec/"python"
      "3.13"
    else
      ENV["UV_PYTHON_PREFERENCE"] = "only-system"
      (formula_opt_bin("python@3.13")/"python3.13").to_s
    end
    ENV["UV_TOOL_DIR"] = libexec/"tools"
    ENV["UV_TOOL_BIN_DIR"] = libexec/"bin"

    system "uv", "tool", "install", ".", "--python", python_arg, "--no-cache"

    # Normalize bundled wheel dylib IDs (including hidden .dylibs directories) to @rpath
    # so preserve_rpath prevents Mach-O header overflow during bottle relocation.
    if OS.mac?
      libexec.glob("**/*.dylib", File::FNM_DOTMATCH).each do |dylib|
        next if dylib.symlink? || !dylib.file?

        change_dylib_id dylib, "@rpath/#{dylib.basename}"
      end
    end

    pkgshare.install "plugins", "configs"

    %w[skillopt-train skillopt-eval skillopt-sleep].each do |cmd|
      (bin/cmd).write <<~SH
        #!/bin/bash
        # Target contract: macOS /bin/bash 3.2+ wrapper.
        set -euo pipefail
        exec "#{libexec}/bin/#{cmd}" "$@"
      SH
      chmod 0755, bin/cmd
    end

    (bin/"skillopt-sleep-mcp").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper; local stdio JSON-RPC MCP server.
      set -euo pipefail
      exec "#{libexec}/tools/skillopt/bin/python" "#{pkgshare}/plugins/copilot/mcp_server.py" "$@"
    SH
    chmod 0755, bin/"skillopt-sleep-mcp"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/skillopt

      `skillopt-sleep` defaults to `--backend mock` (zero API spend) and stages
      proposals for human review; nothing live changes until `skillopt-sleep adopt`.

      Register the local stdio MCP server with:
        #{opt_bin}/skillopt-sleep-mcp

      Bundled agent plugins, skills, and sample experiment configs are installed under:
        #{opt_pkgshare}/plugins
        #{opt_pkgshare}/configs

      This formula does not modify any agent configuration file or cron schedule.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match "usage:", shell_output("#{bin}/skillopt-train --help")
    assert_match "usage:", shell_output("#{bin}/skillopt-eval --help")
    assert_match "SkillOpt-Sleep", shell_output("#{bin}/skillopt-sleep --help")

    proj = testpath/"proj"
    proj.mkpath
    status_out = shell_output("#{bin}/skillopt-sleep status --project #{proj} --json")
    assert_match '"night"', status_out

    requests = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"brew","version":"1"}}}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      {"jsonrpc":"2.0","id":2,"method":"tools/list"}
    JSON
    mcp_out = pipe_output(bin/"skillopt-sleep-mcp", requests, 0)
    assert_match '"name": "skillopt-sleep"', mcp_out
    assert_match '"sleep_status"', mcp_out

    assert_path_exists pkgshare/"plugins/claude-code"
    assert_path_exists pkgshare/"plugins/codex"
  end
end
