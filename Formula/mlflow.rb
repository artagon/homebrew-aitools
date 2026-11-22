class Mlflow < Formula
  desc "AI evaluation, trace, dataset, and skill registry platform with agent CLIs"
  homepage "https://mlflow.org"
  url "https://github.com/mlflow/mlflow/archive/refs/tags/v3.18.0.tar.gz"
  sha256 "6dc9bc1289c123cd2e19c6d98810c2f6e1a1e8353f2b8988f6f924920ca93007"
  license "Apache-2.0"
  head "https://github.com/mlflow/mlflow.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "uv" => :build
  depends_on "node"

  on_linux do
    depends_on "patchelf" => :build
    depends_on "python@3.13"
    depends_on "zlib-ng-compat"
  end

  preserve_rpath

  resource "skills" do
    url "https://github.com/mlflow/skills/archive/6a505d8f30b7fbf93533cdf4e7d88fc30d66ba8b.tar.gz"
    sha256 "0f8ea6a4997c8807cb4f3d8cc0d2bf0fc1e7c38908c6b3bb1d1fce70965d0303"
  end

  def install
    ENV["MLFLOW_DISABLE_TELEMETRY"] = "true"
    ENV["DO_NOT_TRACK"] = "true"
    ENV["YARN_CACHE_FOLDER"] = (buildpath/".yarn-cache").to_s
    ENV["YARN_ENABLE_GLOBAL_CACHE"] = "false"
    ENV["YARN_ENABLE_TELEMETRY"] = "0"

    # Populate the mlflow/assistant/skills submodule directory before building the wheel.
    skills_dir = buildpath/"mlflow/assistant/skills"
    rm_r(skills_dir) if skills_dir.exist?
    resource("skills").stage(skills_dir)

    node_bin = formula_opt_bin("node")/"node"

    # 1. Build the MLflow tracking & skill-registry React UI from source.
    cd "mlflow/server/js" do
      yarn_cjs = Dir["yarn/releases/yarn-*.cjs"].first
      odie "Vendored Yarn release not found in mlflow/server/js/yarn/releases" unless yarn_cjs

      system node_bin, yarn_cjs, "install", "--immutable"
      system node_bin, yarn_cjs, "build"
    end

    # 2. Build TypeScript coding-agent tracing CLIs (@mlflow/codex and @mlflow/claude-code).
    cd "libs/typescript" do
      system "npm", "ci", "--ignore-scripts"
      system "npm", "run", "build:core"
      system "npm", "run", "-C", "integrations/codex", "build"
      system "npm", "run", "-C", "integrations/claude-code", "build"

      (libexec/"ts/node_modules/@mlflow/core").install "core/package.json", "core/dist", "core/bundle"
      (libexec/"ts/integrations/codex").install "integrations/codex/package.json",
                                                "integrations/codex/dist",
                                                "integrations/codex/bundle"
      (libexec/"ts/integrations/claude-code").install "integrations/claude-code/package.json",
                                                      "integrations/claude-code/dist",
                                                      "integrations/claude-code/bundle",
                                                      "integrations/claude-code/hooks",
                                                      "integrations/claude-code/.claude-plugin"
      (pkgshare/"skills").install Dir["integrations/claude-code/skills/*"]
    end

    # 3. Build and install Python mlflow[mcp] into an isolated uv tool environment.
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

    uv_cutoff = "2026-11-18T00:00:00Z"
    wheels_dir = buildpath/"wheels"
    rm(".python-version") if File.exist?(".python-version")
    system "uv", "build", "--wheel", "--python", python_arg,
           "--exclude-newer", uv_cutoff, "--no-cache", "--out-dir", wheels_dir, "."
    (pkgshare/"skills").install Dir[skills_dir/"mlflow-*"]
    mlflow_whl = Dir[wheels_dir/"mlflow-*.whl"].first
    odie "Failed to build mlflow wheel" unless mlflow_whl

    system "uv", "tool", "install", "#{mlflow_whl}[mcp]",
           "--python", python_arg,
           "--exclude-newer", uv_cutoff,
           "--no-cache"

    (libexec/"tools").glob("**/direct_url.json").each(&:unlink)
    receipt = libexec/"tools/mlflow/uv-receipt.toml"
    rm(receipt) if receipt.exist?

    libexec.glob("**/pydevd_attach_to_process/**/*", File::FNM_DOTMATCH).each do |bin_file|
      next unless bin_file.file?

      ext = bin_file.extname.downcase
      next unless %w[.so .dylib .dll .exe .pdb].include?(ext)

      keep = if OS.mac?
        ext == ".dylib" && !(Hardware::CPU.arm? && bin_file.basename.to_s.include?("x86_64"))
      elsif Hardware::CPU.arm?
        ext == ".so" && bin_file.basename.to_s.match?(/aarch64|arm64/)
      else
        ext == ".so" && bin_file.basename.to_s.include?("amd64")
      end
      rm(bin_file) unless keep
    end

    if OS.mac?
      libexec.glob("**/*.dylib", File::FNM_DOTMATCH).each do |dylib|
        next if dylib.symlink? || !dylib.file?

        change_dylib_id dylib, "@rpath/#{dylib.basename}"
      end
    else
      lib_dir = (HOMEBREW_PREFIX/"lib").to_s
      libexec.glob("**/*.so*", File::FNM_DOTMATCH).each do |so|
        next if so.symlink? || !so.file? || so.binread(4) != "\x7fELF"

        needed = Utils.safe_popen_read("patchelf", "--print-needed", so).lines(chomp: true)
        next if needed.exclude?("libz.so.1")

        entries = Utils.safe_popen_read("patchelf", "--print-rpath", so).chomp.split(":").reject(&:empty?)
        next if entries.include?(lib_dir)

        entries << lib_dir
        system "patchelf", "--set-rpath", entries.join(":"), so
      rescue ErrorDuringExecution
        next
      end
    end

    {
      "mlflow"             => [libexec/"bin/mlflow"],
      "mlflow-codex"       => [node_bin, libexec/"ts/integrations/codex/bundle/cli.js"],
      "mlflow-claude-code" => [node_bin, libexec/"ts/integrations/claude-code/bundle/cli.cjs"],
    }.each do |cmd, target_args|
      quoted = target_args.map { |a| "\"#{a}\"" }.join(" ")
      (bin/cmd).write <<~SH
        #!/bin/bash
        # Target contract: macOS /bin/bash 3.2+ wrapper.
        set -euo pipefail

        export MLFLOW_DISABLE_TELEMETRY="${MLFLOW_DISABLE_TELEMETRY:-true}"
        export MLFLOW_DISABLE_AGENT_HINT="${MLFLOW_DISABLE_AGENT_HINT:-1}"
        export DO_NOT_TRACK="${DO_NOT_TRACK:-true}"

        exec #{quoted} "$@"
      SH
      chmod 0755, bin/cmd
    end
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/mlflow

      MLflow telemetry is disabled by default (`MLFLOW_DISABLE_TELEMETRY=true`,
      `DO_NOT_TRACK=true`).

      Start a local SQLite-backed tracking and skill-registry server on loopback:
        mlflow server --host 127.0.0.1 --port 5000 --backend-store-uri sqlite:///mlflow.db

      Register the local stdio MCP server with:
        #{opt_bin}/mlflow mcp run

      Coding-agent tracing CLIs (`mlflow-codex` and `mlflow-claude-code`) are installed
      in `#{opt_bin}`, and bundled skills are installed under:
        #{opt_pkgshare}/skills

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match version.to_s, shell_output("#{bin}/mlflow --version")
    assert_match "mlflow-evaluation", shell_output("#{bin}/mlflow skills list")
    assert_match "Usage:", shell_output("#{bin}/mlflow-codex --help 2>&1")
    assert_match "Usage:", shell_output("#{bin}/mlflow-claude-code --help 2>&1")

    # Verify stdio MCP server initialization and tool listing.
    ENV["MLFLOW_TRACKING_URI"] = "sqlite:///#{testpath}/mcp.db"
    requests = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"brew","version":"1"}}}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      {"jsonrpc":"2.0","id":2,"method":"tools/list"}
    JSON
    mcp_out = pipe_output("#{bin}/mlflow mcp run", requests, 0)
    assert_match "protocolVersion", mcp_out

    # Verify local SQLite tracking + skill registry register & pull round-trip.
    port = free_port
    db_uri = "sqlite:///#{testpath}/mlflow.db"
    art_dir = testpath/"artifacts"
    pid = spawn(
      bin/"mlflow", "server",
      "--host", "127.0.0.1",
      "--port", port.to_s,
      "--backend-store-uri", db_uri,
      "--default-artifact-root", art_dir.to_s,
      "--workers", "1"
    )
    begin
      ENV["MLFLOW_TRACKING_URI"] = "http://127.0.0.1:#{port}"
      healthy = false
      30.times do
        out = Utils.popen_read("curl", "-fsS", "http://127.0.0.1:#{port}/health")
        if $CHILD_STATUS.success? && out.strip == "OK"
          healthy = true
          break
        end
        sleep 1
      end
      assert healthy, "mlflow server failed to become healthy on 127.0.0.1:#{port}"

      skill_src = testpath/"skills/code-review"
      skill_src.mkpath
      (skill_src/"SKILL.md").write <<~MD
        ---
        name: code-review
        description: Verifier-first code review skill
        ---
        Check invariants before approving changes.
      MD

      reg_json = JSON.parse(
        shell_output("#{bin}/mlflow skills register --source #{skill_src} --output json"),
      )
      assert_includes reg_json.to_json, "code-review"

      pulled = testpath/"pulled/code-review"
      system bin/"mlflow", "skills", "pull", "skills:/code-review/1", "--destination", pulled
      assert_path_exists pulled/"SKILL.md"
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end

    assert_path_exists pkgshare/"skills/mlflow-evaluation/SKILL.md"
  end
end
