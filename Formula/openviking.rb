class Openviking < Formula
  desc "Agent-native context database for AI memory, RAG, and skills"
  homepage "https://github.com/volcengine/OpenViking"
  version "0.5.6"
  license "AGPL-3.0-only"

  livecheck do
    url :homepage
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/openviking-0.5.6"
    rebuild 1
    sha256 cellar: :any, arm64_tahoe:  "f9bef78c0a38a507cce2e59b20215fc3d04214d58ca11473bd0bb8b0e199104d"
    sha256 cellar: :any, arm64_linux:  "d4d4aea0e2b5a7a7c685e1f73eb16c1d4603246e9a01ff8adabb0f07db6b78dc"
    sha256 cellar: :any, x86_64_linux: "b0e39afd77bb14c810847cf61eefe973ba4ffe59cb9a8da9067b2ca4ebaa0e27"
  end

  depends_on "uv" => :build

  # SHA-256-pinned official platform cp310-abi3 wheels (bundling native Rust ov CLI,
  # ragfs_python, C++ vectordb SIMD engine, and prebuilt Web Studio SPA).
  on_macos do
    on_arm do
      url "https://files.pythonhosted.org/packages/7b/72/d5b42340d7f0b238004198d6ee4be2643049d51eebabe1d526a6f19c066c/openviking-0.5.6-cp310-abi3-macosx_14_0_arm64.whl"
      sha256 "051e409cc42657b98ac3b8b49e1a55f6684c54c73f21042ef65a7f106b4b6c88"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/57/a1/263fa24b9ed1d96f3ba34de22f1ba41f60fa381c5a4a1fb612b52afb85bf/openviking-0.5.6-cp310-abi3-macosx_15_0_x86_64.whl"
      sha256 "260f55bf34c9a596e385018ac8bacde037a4e7b8ebe056700b3d6b6b28392846"
    end
  end

  on_linux do
    depends_on "patchelf" => :build
    depends_on "python@3.13"
    depends_on "zlib-ng-compat"

    on_arm do
      url "https://files.pythonhosted.org/packages/82/7f/cf06d6bf02d5d6a4e400ba6a0c17881974c90049326448876af8eac96d6c/openviking-0.5.6-cp310-abi3-manylinux_2_31_aarch64.whl"
      sha256 "fdaa808cf5c55411f9b33f8b1c607eb5675163f7c27e73c637a1e7075bcfd458"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/ad/93/4879a222a198edc2524ba5629b92a83649ce94868e21d9af65284fccf3a1/openviking-0.5.6-cp310-abi3-manylinux_2_31_x86_64.whl"
      sha256 "9f6651d96116d932341be3a6cb0f34c1d019c17159a8288fef6d1912247e67a6"
    end
  end

  conflicts_with "ov", because: "both install `ov` binaries"

  preserve_rpath

  resource "openviking-source" do
    url "https://github.com/volcengine/OpenViking/archive/refs/tags/v0.5.6.tar.gz"
    sha256 "667483b482abb0f04af24cf10daa991efaecc72897266604c1fe9a30cc718ed3"
  end

  resource "openviking-sdk" do
    url "https://files.pythonhosted.org/packages/8a/58/909c6f9bbece66ed92bca9f2ce7ff375095c6f79644d50d1ef64deb3a2f0/openviking_sdk-0.1.21-py3-none-any.whl"
    sha256 "9e40e050b85cf978f1e96af2c1724ad83c23b321ff99effd9933508755da29b0"
  end

  def install
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

    wheelhouse = buildpath/"wheelhouse"
    wheelhouse.mkpath
    staged_whl = buildpath.glob("openviking-*.whl").fetch(0)
    cp staged_whl, wheelhouse/staged_whl.basename
    ov_wheel = wheelhouse/staged_whl.basename
    resource("openviking-sdk").stage do
      whl = Pathname.pwd.glob("openviking_sdk-*.whl").fetch(0)
      cp whl, wheelhouse/whl.basename
    end

    # Install the SHA-256-pinned platform wheel and SDK while pinning transitive
    # PyPI dependencies to a fixed cutoff timestamp.
    exclude_newer = "2026-11-25T00:00:00Z"
    system "uv", "tool", "install", ov_wheel,
           "--python", python_arg,
           "--find-links", wheelhouse,
           "--exclude-newer", exclude_newer,
           "--no-cache"

    (libexec/"tools").glob("**/direct_url.json").each { |file| rm(file) }
    (libexec/"tools").glob("**/uv-receipt.toml").each { |file| rm(file) }

    # Ensure bare native binaries staged inside libexec are executable.
    (libexec/"tools").glob("**/openviking/bin/ov").each do |ov_bin|
      chmod 0755, ov_bin if ov_bin.file?
    end

    os_tag = OS.mac? ? "darwin" : "linux"
    arch_tag = Hardware::CPU.arm? ? "arm64" : "x64"
    native_tag = "#{os_tag}-#{arch_tag}"
    (libexec/"tools").glob("**/prebuilds/*").each do |entry|
      name = entry.basename.to_s
      next if name == native_tag || name.start_with?("#{native_tag}.")

      entry.directory? ? rm_r(entry) : rm(entry)
    end
    (libexec/"tools").glob("**/pydevd_attach_to_process").each { |dir| rm_r(dir) if dir.directory? }

    # Normalize bundled dylib IDs (including hidden directories) to @rpath on macOS,
    # and append HOMEBREW_PREFIX/lib to Linux ELF shared objects and binaries linking libz.so.1.
    if OS.mac?
      libexec.glob("**/*.dylib", File::FNM_DOTMATCH).each do |dylib|
        next if dylib.symlink? || !dylib.file?

        change_dylib_id dylib, "@rpath/#{dylib.basename}"
      end
    else
      lib_dir = (HOMEBREW_PREFIX/"lib").to_s
      libexec.glob("**/*", File::FNM_DOTMATCH).each do |elf|
        next if elf.symlink? || !elf.file? || elf.size < 4 || elf.binread(4) != "\x7fELF"

        needed = Utils.safe_popen_read("patchelf", "--print-needed", elf).lines(chomp: true)
        next if needed.exclude?("libz.so.1")

        entries = Utils.safe_popen_read("patchelf", "--print-rpath", elf).chomp.split(":").reject(&:empty?)
        next if entries.include?(lib_dir)

        entries << lib_dir
        system "patchelf", "--set-rpath", entries.join(":"), elf
      rescue ErrorDuringExecution
        next
      end
    end

    # Stage license, passive agent plugins, skills, manifests, and loopback-hardened example configs.
    resource("openviking-source").stage do
      prefix.install "LICENSE"
      inreplace "examples/ov.conf.example", '"host": "0.0.0.0"', '"host": "127.0.0.1"'
      pkgshare.install ".claude-plugin", ".agents", "agent-plugins"
      (pkgshare/"skills").mkpath
      (pkgshare/"agent-plugins/skills").children.each do |skill_dir|
        cp_r skill_dir, pkgshare/"skills"/skill_dir.basename
      end
      (pkgshare/"plugins").install "examples/claude-code-memory-plugin" => "claude-code"
      (pkgshare/"plugins").install "examples/codex-memory-plugin" => "codex"
      (pkgshare/"plugins").install "examples/opencode-plugin" => "opencode"
      (pkgshare/"plugins").install "examples/agent-hook-plugin" => "agent-hook"
      (pkgshare/"examples").install "examples/ov.conf.example",
                                    "examples/ovcli.conf.example",
                                    "examples/workspace-config.example.json"
    end

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `openviking` (`artagon/aitools/openviking`)

      - **Binaries:** `openviking`, `ov` (`conflicts_with "ov"`), `openviking-server`, `openviking-gateway`
      - **Config files:** `ov.conf` (`--config`, template at `#{opt_pkgshare}/examples/ov.conf.example`), `ovcli.conf` (`OPENVIKING_CLI_CONFIG_FILE`), `~/.openviking/gateway.conf` (`OPENVIKING_GATEWAY_CONFIG_FILE`)
      - **Non-interactive CLI requirement:** Set `OPENVIKING_LANG=en` (or run `ov language en` once) so non-interactive `ov`/`openviking` does not exit `2`.
      - **Hardening:** `openviking-server` defaults `--host 127.0.0.1` (`OPENVIKING_HOST` / `--host` overrides), `openviking-gateway` defaults `OPENVIKING_GATEWAY_HOST=127.0.0.1`, all 4 wrappers disable telemetry/OTel (`DO_NOT_TRACK=1`, `OTEL_SDK_DISABLED=true`, `SCARF_NO_ANALYTICS=true`, `LITELLM_LOCAL_MODEL_COST_MAP=True`) and block top-level `update`/`self-update`/`upgrade` (`exit 2`, preserving `ov skills update`).
      - **Workspace hygiene:** Set an explicit absolute `storage.workspace` in `ov.conf` to avoid `./data` in the current repo.
      - **Passive assets:** `#{opt_pkgshare}/{agent-plugins,skills,plugins,examples}`
      - **Upgrade:** `brew upgrade artagon/aitools/openviking`
    MARKDOWN

    hardened_env = <<~SH.chomp
      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
      export OTEL_SDK_DISABLED="${OTEL_SDK_DISABLED:-true}"
      export OTEL_TRACES_EXPORTER="${OTEL_TRACES_EXPORTER:-none}"
      export OTEL_METRICS_EXPORTER="${OTEL_METRICS_EXPORTER:-none}"
      export OTEL_LOGS_EXPORTER="${OTEL_LOGS_EXPORTER:-none}"
      export SCARF_NO_ANALYTICS="${SCARF_NO_ANALYTICS:-true}"
      export ANONYMIZED_TELEMETRY="${ANONYMIZED_TELEMETRY:-false}"
      export LITELLM_LOCAL_MODEL_COST_MAP="${LITELLM_LOCAL_MODEL_COST_MAP:-True}"
      export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
      export PYTHONUTF8="${PYTHONUTF8:-1}"
    SH

    %w[openviking ov].each do |cmd|
      (bin/cmd).write <<~SH
        #!/bin/bash
        # Target contract: macOS /bin/bash 3.2+ wrapper.
        set -euo pipefail

        #{hardened_env}

        skip_next=0
        for arg in "$@"; do
          if [[ "${skip_next}" -eq 1 ]]; then
            skip_next=0
            continue
          fi
          case "${arg}" in
            --)
              break
              ;;
            -h | --help | -V | --version)
              break
              ;;
            -o | --output | --account | --user | --actor-peer-id)
              skip_next=1
              ;;
            -*)
              ;;
            update | self-update | upgrade)
              printf '%s\\n' "Error: Homebrew manages openviking upgrades. Run: brew upgrade artagon/aitools/openviking" >&2
              exit 2
              ;;
            *)
              break
              ;;
          esac
        done

        exec "#{libexec}/bin/#{cmd}" "$@"
      SH
      chmod 0755, bin/cmd
    end

    (bin/"openviking-server").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      #{hardened_env}

      has_host=0
      skip_host_default=0
      skip_next=0
      seen_subcmd=0
      for arg in "$@"; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        case "${arg}" in
          --)
            break
            ;;
          --host)
            has_host=1
            skip_next=1
            ;;
          --host=*)
            has_host=1
            ;;
          -h | --help | -V | --version)
            skip_host_default=1
            break
            ;;
          --port | --config | --workers | --bot-port | --bot-log-dir)
            skip_next=1
            ;;
          -*)
            ;;
          *)
            if [[ "${seen_subcmd}" -eq 0 ]]; then
              seen_subcmd=1
              skip_host_default=1
              case "${arg}" in
                update | self-update | upgrade)
                  printf '%s\\n' "Error: Homebrew manages openviking upgrades. Run: brew upgrade artagon/aitools/openviking" >&2
                  exit 2
                  ;;
              esac
            fi
            break
            ;;
        esac
      done

      if [[ "${has_host}" -eq 0 && "${skip_host_default}" -eq 0 ]]; then
        exec "#{libexec}/bin/openviking-server" --host "${OPENVIKING_HOST:-127.0.0.1}" "$@"
      fi
      exec "#{libexec}/bin/openviking-server" "$@"
    SH
    chmod 0755, bin/"openviking-server"

    (bin/"openviking-gateway").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      #{hardened_env}
      export OPENVIKING_GATEWAY_HOST="${OPENVIKING_GATEWAY_HOST:-127.0.0.1}"

      skip_next=0
      for arg in "$@"; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        case "${arg}" in
          --)
            break
            ;;
          -h | --help | -V | --version)
            break
            ;;
          --config)
            skip_next=1
            ;;
          -*)
            ;;
          update | self-update | upgrade)
            printf '%s\\n' "Error: Homebrew manages openviking upgrades. Run: brew upgrade artagon/aitools/openviking" >&2
            exit 2
            ;;
          *)
            break
            ;;
        esac
      done

      exec "#{libexec}/bin/openviking-gateway" "$@"
    SH
    chmod 0755, bin/"openviking-gateway"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `openviking update`, `ov update`,
      `self-update`, or `upgrade`. Use:
        brew upgrade artagon/aitools/openviking

      Hardened local defaults in `openviking`, `ov`, `openviking-server`, and `openviking-gateway`:
        - Loopback bind by default (`127.0.0.1:1933` for `openviking-server`,
          `127.0.0.1:1935` for `openviking-gateway`; override with `--host`,
          `OPENVIKING_HOST`, or `OPENVIKING_GATEWAY_HOST`)
        - Telemetry and OpenTelemetry export disabled by default
          (`DO_NOT_TRACK=1`, `OTEL_SDK_DISABLED=true`, `LITELLM_LOCAL_MODEL_COST_MAP=True`)

      First non-interactive CLI invocation requires a display language (`ov language en`
      or `OPENVIKING_LANG=en`).

      Note: `bin/ov` conflicts with Homebrew core's `ov` terminal pager; use `openviking`
      or keep only one formula linked.

      Passive agent plugins, Agent Plugins 1.0 skills, marketplace manifests, example
      configs, and package agent guide are staged under:
        #{opt_pkgshare}/agent-plugins
        #{opt_pkgshare}/skills
        #{opt_pkgshare}/plugins
        #{opt_pkgshare}/examples
        #{opt_share}/doc/openviking/AGENTS.md

      This formula does not modify any agent configuration, skill, hook, or plugin file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s
    ENV["OPENVIKING_LANG"] = "en"

    assert_match version.to_s, shell_output("#{bin}/openviking --version")
    assert_match version.to_s, shell_output("#{bin}/ov --version")
    assert_match version.to_s, shell_output("#{bin}/openviking-server --version")
    assert_match "OpenViking Gateway", shell_output("#{bin}/openviking-gateway --help")

    assert_match "brew upgrade artagon/aitools/openviking", shell_output("#{bin}/openviking update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/openviking", shell_output("#{bin}/ov self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/openviking", shell_output("#{bin}/openviking upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/openviking", shell_output("#{bin}/openviking-server update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/openviking", shell_output("#{bin}/openviking-gateway upgrade 2>&1", 2)

    # Legitimate subcommands, help flags, and option values named "update" must not be blocked.
    refute_match "Homebrew manages openviking upgrades", shell_output("#{bin}/openviking skills update --help 2>&1")
    assert_match version.to_s, shell_output("#{bin}/ov --account update --version")
    refute_match "Homebrew manages openviking upgrades", shell_output("#{bin}/ov -h update 2>&1")

    gw_probe_src = (bin/"openviking-gateway").read
    refute_nil gw_probe_src.sub!(%Q(exec "#{libexec}/bin/openviking-gateway" "$@"), "exec /usr/bin/env")
    gw_probe = testpath/"ov-gw-probe"
    gw_probe.write(gw_probe_src)
    chmod 0755, gw_probe
    gw_env = shell_output(
      "env -u OPENVIKING_GATEWAY_HOST -u DO_NOT_TRACK -u OTEL_SDK_DISABLED #{gw_probe}",
    )
    assert_match(/^OPENVIKING_GATEWAY_HOST=127\.0\.0\.1$/, gw_env)
    assert_match(/^DO_NOT_TRACK=1$/, gw_env)
    assert_match(/^OTEL_SDK_DISABLED=true$/, gw_env)

    # Verify native Rust ragfs_python and C++ vectordb engine extensions load cleanly.
    venv_py = libexec/"tools/openviking/bin/python"
    system venv_py, "-c", <<~PY
      import openviking
      from openviking.pyagfs import get_binding_client
      from openviking.storage.vectordb.engine import ENGINE_VARIANT

      assert openviking.__version__
      assert ENGINE_VARIANT != "unavailable", f"unexpected engine variant: {ENGINE_VARIANT}"
      assert get_binding_client() is not None
    PY

    # Boot openviking-server locally; even when ov.conf sets host=0.0.0.0 without
    # root_api_key, the wrapper enforces --host 127.0.0.1 so local dev mode starts cleanly.
    port = free_port
    ov_conf = testpath/"ov.conf"
    ov_conf.write JSON.pretty_generate({
      server:  { host: "0.0.0.0", port: port },
      storage: { workspace: (testpath/"data").to_s },
    })

    cli_conf = testpath/"ovcli.conf"
    cli_conf.write JSON.pretty_generate({ url: "http://127.0.0.1:#{port}" })
    ENV["OPENVIKING_CLI_CONFIG_FILE"] = cli_conf.to_s

    srv_pid = spawn(bin/"openviking-server", "--config", ov_conf.to_s, "--port", port.to_s)
    begin
      require "net/http"
      health_uri = URI("http://127.0.0.1:#{port}/health")
      healthy = false
      60.times do
        begin
          res = Net::HTTP.get_response(health_uri)
          if res.is_a?(Net::HTTPSuccess) && !res.body.to_s.empty?
            payload = JSON.parse(res.body)
            if payload["healthy"] == true && payload["status"] == "ok"
              assert_equal version.to_s, payload["version"]
              healthy = true
              break
            end
          end
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError, Net::ReadTimeout, SocketError
          nil
        end
        sleep 0.5
      end
      assert healthy, "openviking-server failed to become healthy on 127.0.0.1:#{port}"

      cli_health = JSON.parse(shell_output("#{bin}/openviking --output json health"))
      assert cli_health["ok"]
      assert_equal true, cli_health.dig("result", "healthy")
    ensure
      begin
        Process.kill("TERM", srv_pid)
      rescue Errno::ESRCH
        nil
      end
      begin
        Process.wait(srv_pid)
      rescue Errno::ECHILD
        nil
      end
    end

    assert_path_exists prefix/"LICENSE"
    assert_path_exists pkgshare/".claude-plugin/marketplace.json"
    assert_path_exists pkgshare/".agents/plugins/marketplace.json"
    assert_path_exists pkgshare/"agent-plugins/plugin.json"
    assert_path_exists pkgshare/"skills/openviking-memory/SKILL.md"
    assert_path_exists pkgshare/"plugins/claude-code/.claude-plugin/plugin.json"
    assert_path_exists pkgshare/"plugins/codex/.codex-plugin/plugin.json"
    assert_path_exists pkgshare/"examples/ov.conf.example"
    assert_path_exists doc/"AGENTS.md"
    assert_match '"host": "127.0.0.1"', (pkgshare/"examples/ov.conf.example").read
    refute_match '"host": "0.0.0.0"', (pkgshare/"examples/ov.conf.example").read

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".agents"
  end
end
