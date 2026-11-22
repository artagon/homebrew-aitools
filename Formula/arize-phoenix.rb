class ArizePhoenix < Formula
  desc "Local-first OpenTelemetry AI observability and evaluation server"
  homepage "https://arize.com/docs/phoenix"
  url "https://github.com/Arize-ai/phoenix/archive/refs/tags/arize-phoenix-v21.1.0.tar.gz"
  sha256 "896380a6b3db76ebd4ea89e8c81e7f54be865e072faa2c19614f1cf18e150d55"
  license "Elastic-2.0"
  head "https://github.com/Arize-ai/phoenix.git", branch: "main"

  livecheck do
    url :stable
    regex(/^arize-phoenix[._-]v?(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/arize-phoenix-21.1.0"
    rebuild 1
    sha256 cellar: :any, arm64_tahoe:  "b28f079dafc476e74f466a39ccf4e1e167167ab0313f88a4779058083ae3fffe"
    sha256 cellar: :any, arm64_linux:  "383b3bdb5d6fb95dfae0086e55f02c6e10f901eb42ce98bb4f747e0fa7c88721"
    sha256 cellar: :any, x86_64_linux: "f0b79fb020736b7744fc06470c4398eefe3348acd3a590e7231182f44537e8fe"
  end

  depends_on "node" => :build
  depends_on "pnpm" => :build
  depends_on "uv" => :build

  on_linux do
    depends_on "python@3.13"
  end

  preserve_rpath

  def install
    ENV["COREPACK_ENABLE_STRICT"] = "0"
    ENV["PNPM_HOME"] = (buildpath/".pnpm-home").to_s
    ENV["SCARF_NO_ANALYTICS"] = "true"
    ENV["DO_NOT_TRACK"] = "true"

    inreplace "js/package.json", /,\s*"packageManager":\s*"[^"]+"/, ""
    inreplace "pyproject.toml", /^required-version = .*\n/, ""
    inreplace "pyproject.toml", /^exclude-newer = .*\n/, ""
    rm(".python-version") if File.exist?(".python-version")

    # 1. Build the Phoenix React web UI into src/phoenix/server/static.
    cd "js" do
      system "pnpm", "install", "--frozen-lockfile"
      system "pnpm", "--filter", "phoenix-ui...", "run", "build"
    end

    # 2. Build local workspace wheels and install arize-phoenix into an isolated uv venv.
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
    %w[packages/phoenix-client packages/phoenix-evals packages/phoenix-otel .].each do |pkg_dir|
      rm(Pathname(pkg_dir)/".python-version") if (Pathname(pkg_dir)/".python-version").exist?
      system "uv", "build", "--wheel", "--python", python_arg,
             "--exclude-newer", uv_cutoff, "--no-cache", "--out-dir", wheels_dir, pkg_dir
    end

    server_whl = Dir[wheels_dir/"arize_phoenix-*.whl"].first
    client_whl = Dir[wheels_dir/"arize_phoenix_client-*.whl"].first
    evals_whl = Dir[wheels_dir/"arize_phoenix_evals-*.whl"].first
    otel_whl = Dir[wheels_dir/"arize_phoenix_otel-*.whl"].first
    if [server_whl, client_whl, evals_whl, otel_whl].any?(&:nil?)
      odie "Failed to build arize-phoenix workspace wheels"
    end

    system "uv", "tool", "install", server_whl,
           "--python", python_arg,
           "--exclude-newer", uv_cutoff,
           "--no-cache",
           "--with", client_whl,
           "--with", evals_whl,
           "--with", otel_whl

    (libexec/"tools").glob("**/direct_url.json").each(&:unlink)
    receipt = libexec/"tools/arize-phoenix/uv-receipt.toml"
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
    end

    prefix.install "LICENSE", "IP_NOTICE"
    (pkgshare/"skills").install Dir["skills/phoenix-*"]
    (pkgshare/"plugins").install "plugins/claude", "plugins/codex"

    %w[phoenix arize-phoenix].each do |cmd|
      (bin/cmd).write <<~SH
        #!/bin/bash
        # Target contract: macOS /bin/bash 3.2+ wrapper.
        set -euo pipefail

        export PHOENIX_HOST="${PHOENIX_HOST:-127.0.0.1}"
        export PHOENIX_TELEMETRY_ENABLED="${PHOENIX_TELEMETRY_ENABLED:-false}"
        export PHOENIX_DISABLE_MODEL_COST_AUTO_UPDATE="${PHOENIX_DISABLE_MODEL_COST_AUTO_UPDATE:-true}"
        export PHOENIX_ALLOW_EXTERNAL_RESOURCES="${PHOENIX_ALLOW_EXTERNAL_RESOURCES:-false}"
        export SCARF_NO_ANALYTICS="${SCARF_NO_ANALYTICS:-true}"
        export DO_NOT_TRACK="${DO_NOT_TRACK:-true}"

        exec "#{libexec}/bin/#{cmd}" "$@"
      SH
      chmod 0755, bin/cmd
    end
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/arize-phoenix

      Arize Phoenix server is licensed under Elastic License 2.0 (`Elastic-2.0`);
      OpenInference packages remain `Apache-2.0`. See:
        #{opt_prefix}/LICENSE
        #{opt_prefix}/IP_NOTICE

      Hardened local defaults in `phoenix` and `arize-phoenix`:
        - Loopback bind (`PHOENIX_HOST=127.0.0.1`, HTTP port `6006`)
        - FullStory and Scarf telemetry disabled (`PHOENIX_TELEMETRY_ENABLED=false`)
        - Background internet fetches and model-price auto-updates disabled
          (`PHOENIX_ALLOW_EXTERNAL_RESOURCES=false`, `PHOENIX_DISABLE_MODEL_COST_AUTO_UPDATE=true`)

      Start a persistent local SQLite-backed Phoenix workbench with:
        PHOENIX_WORKING_DIR=~/.local/share/phoenix phoenix serve

      Bundled skills and coding-agent plugins are installed under:
        #{opt_pkgshare}/skills
        #{opt_pkgshare}/plugins

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["PHOENIX_WORKING_DIR"] = (testpath/"phoenix-data").to_s
    (testpath/"phoenix-data").mkpath

    assert_match "usage: phoenix", shell_output("#{bin}/phoenix --help")
    assert_match "usage: phoenix", shell_output("#{bin}/arize-phoenix --help")

    port = free_port
    grpc_port = free_port
    ENV["PHOENIX_PORT"] = port.to_s
    ENV["PHOENIX_GRPC_PORT"] = grpc_port.to_s

    pid = spawn(bin/"phoenix", "serve")
    begin
      healthy = false
      40.times do
        out = Utils.popen_read("curl", "-fsS", "http://127.0.0.1:#{port}/healthz")
        if $CHILD_STATUS.success?
          healthy = true
          assert_includes out, "OK" if out.present?
          break
        end
        sleep 1
      end
      assert healthy, "phoenix serve failed to respond on http://127.0.0.1:#{port}/healthz"
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end

    assert_path_exists prefix/"LICENSE"
    assert_path_exists prefix/"IP_NOTICE"
    assert_path_exists pkgshare/"skills/phoenix-evals/SKILL.md"
  end
end
