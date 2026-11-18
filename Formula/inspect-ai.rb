class InspectAi < Formula
  desc "Agentic LLM evaluation harness bundling Inspect SWE and MLflow hooks"
  homepage "https://inspect.aisi.org.uk/"
  url "https://github.com/UKGovernmentBEIS/inspect_ai/archive/refs/tags/0.3.290.tar.gz"
  sha256 "d1ad29583dde1d5c5636eca232cbd22cecf59e4fbed631795fb8f43be39ca923"
  license "MIT"
  head "https://github.com/UKGovernmentBEIS/inspect_ai.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "uv" => :build

  on_linux do
    depends_on "python@3.13"
  end

  preserve_rpath

  resource "inspect-swe" do
    url "https://github.com/meridianlabs-ai/inspect_swe/archive/refs/tags/0.3.0.tar.gz"
    sha256 "3b3778011e1d973749d269003445c0cef4e7647ac8144bad397654192aca985c"
  end

  resource "inspect-mlflow" do
    url "https://github.com/debu-sinha/inspect-mlflow/archive/refs/tags/v0.9.0.tar.gz"
    sha256 "31e7e982e8b06c32108da587f470eba5f29905976d8c2836c0f1c3b6baafc8da"
  end

  def install
    # Replace upstream's moving uv version/cooldown constraints with a fixed release cutoff.
    uv_cutoff = "2026-11-18T00:00:00Z"
    inreplace "pyproject.toml", /^required-version = .*\n/, ""
    inreplace "pyproject.toml", /^exclude-newer = .*\n/, ""

    swe_dir = buildpath/"vendor-inspect-swe"
    resource("inspect-swe").stage(swe_dir)
    inreplace swe_dir/"pyproject.toml", /^required-version = .*\n/, ""
    inreplace swe_dir/"pyproject.toml", /^exclude-newer = .*\n/, ""

    mlflow_ext_dir = buildpath/"vendor-inspect-mlflow"
    resource("inspect-mlflow").stage(mlflow_ext_dir)

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

    wheels_dir = buildpath/"wheels"
    [buildpath, swe_dir, mlflow_ext_dir].each do |dir|
      rm(dir/".python-version") if (dir/".python-version").exist?
    end
    with_env("SETUPTOOLS_SCM_PRETEND_VERSION" => version.to_s) do
      system "uv", "build", "--wheel", "--python", python_arg,
             "--exclude-newer", uv_cutoff, "--no-cache", "--out-dir", wheels_dir, "."
    end
    with_env("SETUPTOOLS_SCM_PRETEND_VERSION" => resource("inspect-swe").version.to_s) do
      system "uv", "build", "--wheel", "--python", python_arg,
             "--exclude-newer", uv_cutoff, "--no-cache", "--out-dir", wheels_dir, swe_dir
    end
    system "uv", "build", "--wheel", "--python", python_arg,
           "--exclude-newer", uv_cutoff, "--no-cache", "--out-dir", wheels_dir, mlflow_ext_dir

    inspect_whl = Dir[wheels_dir/"inspect_ai-*.whl"].first
    swe_whl = Dir[wheels_dir/"inspect_swe-*.whl"].first
    mlflow_ext_whl = Dir[wheels_dir/"inspect_mlflow-*.whl"].first
    if [inspect_whl, swe_whl, mlflow_ext_whl].any?(&:nil?)
      odie "Failed to build local wheels for inspect-ai bundle"
    end

    system "uv", "tool", "install", inspect_whl,
           "--python", python_arg,
           "--exclude-newer", uv_cutoff,
           "--no-cache",
           "--with", swe_whl,
           "--with", mlflow_ext_whl,
           "--with", "mcp>=1.10.0",
           "--with", "anthropic>=2.0.0",
           "--with", "openai>=3.4.0",
           "--with", "google-genai>=3.3.0"

    # Remove buildpath wheel path metadata recorded by pip/uv so bottles remain relocatable.
    (libexec/"tools").glob("**/direct_url.json").each(&:unlink)
    receipt = libexec/"tools/inspect-ai/uv-receipt.toml"
    rm(receipt) if receipt.exist?

    # Prune foreign-OS/CPU prebuilt debugpy attach binaries so Linux/macOS bottle audits pass cleanly.
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

    (bin/"inspect").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export MLFLOW_DISABLE_TELEMETRY="${MLFLOW_DISABLE_TELEMETRY:-true}"
      export MLFLOW_DISABLE_AGENT_HINT="${MLFLOW_DISABLE_AGENT_HINT:-1}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-true}"

      exec "#{libexec}/bin/inspect" "$@"
    SH
    chmod 0755, bin/"inspect"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/inspect-ai

      `inspect` runs in an isolated `uv` tool environment pre-bundled with:
        - `inspect-swe` #{resource("inspect-swe").version} (`claude_code`, `codex_cli`, `antigravity`, `gemini_cli`, `kimi_code`)
        - `inspect-mlflow` #{resource("inspect-mlflow").version} (`MLFLOW_INSPECT_TRACING=true` tracking/tracing hooks)
        - `mcp`, `anthropic`, `openai`, and `google-genai` model providers

      Note: Inspect AI is a Python evaluation framework. For evaluation suites that
      import custom project dependencies or lock exact trial versions, pin `inspect-ai`
      and `inspect-swe` in your project's `uv.lock` and invoke `uv run inspect eval`.

      MLflow telemetry is disabled by default (`MLFLOW_DISABLE_TELEMETRY=true`).
      This formula does not modify any agent configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s

    assert_equal version.to_s, shell_output("#{bin}/inspect --version").strip

    # Verify bundled inspect_swe agents and inspect_mlflow hooks import cleanly.
    venv_py = libexec/"tools/inspect-ai/bin/python"
    system venv_py, "-c", <<~PY
      import inspect_ai
      import inspect_mlflow
      from inspect_swe import claude_code, codex_cli
      assert callable(claude_code) and callable(codex_cli)
    PY

    # Run a complete offline evaluation trial using Inspect's mockllm provider.
    (testpath/"trial_task.py").write <<~PY
      from inspect_ai import Task, task
      from inspect_ai.dataset import Sample
      from inspect_ai.model import ModelOutput, ModelUsage, get_model
      from inspect_ai.scorer import includes
      from inspect_ai.solver import generate

      @task
      def smoke_eval():
          out = ModelOutput.from_content(model="mockllm/model", content="Default output")
          out.usage = ModelUsage(input_tokens=2, output_tokens=2, total_tokens=4)
          mock = get_model("mockllm/model", custom_outputs=[out])
          return Task(
              dataset=[Sample(input="Say hello", target="Default output")],
              solver=[generate()],
              scorer=includes(),
              model=mock,
          )
    PY

    log_dir = testpath/"logs"
    system bin/"inspect", "eval", testpath/"trial_task.py",
           "--display", "none",
           "--log-dir", log_dir
    logs_out = shell_output("#{bin}/inspect log list --log-dir #{log_dir} --json")
    assert_operator JSON.parse(logs_out).length, :>=, 1
  end
end
