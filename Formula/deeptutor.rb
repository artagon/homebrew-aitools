class Deeptutor < Formula
  desc "Agent-native intelligent learning companion CLI and SDK"
  homepage "https://github.com/HKUDS/DeepTutor"
  url "https://github.com/HKUDS/DeepTutor/archive/refs/tags/v1.7.4.tar.gz"
  sha256 "2dd44ba5e9f1da3c13d81dd1cfe6b876f03b47e5d133b41c3bcd71d4b32f4207"
  license "Apache-2.0"
  head "https://github.com/HKUDS/DeepTutor.git", branch: "main"

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
    buildpath.glob("**/.python-version").each { |file| rm(file) }

    # Default local servers to loopback and disable in-app version checks and
    # self-updates so Homebrew retains upgrade ownership.
    inreplace "deeptutor_cli/main.py",
              'host: str = typer.Option("0.0.0.0", help="Bind address."),',
              'host: str = typer.Option("127.0.0.1", help="Bind address."),'
    inreplace "deeptutor/runtime/launcher.py" do |s|
      s.gsub! 'common_env["HOSTNAME"] = "0.0.0.0"',
              'common_env["HOSTNAME"] = os.environ.get("DEEPTUTOR_HOST") or "127.0.0.1"'
      s.gsub! "\"--host\",\n        \"0.0.0.0\",",
              "\"--host\",\n        \"127.0.0.1\","
    end
    inreplace "deeptutor/services/config/runtime_settings.py",
              '"version_check_enabled": True,',
              '"version_check_enabled": False,'
    inreplace "deeptutor/services/app_update.py",
              '    """Classify only layouts whose update ownership is unambiguous."""',
              <<~PYTHON.chomp.gsub(/^/, "    ")
                """Classify only layouts whose update ownership is unambiguous."""
                return Installation(
                    mode="unknown",
                    current_version=__version__,
                    automatic_update=False,
                    command="brew upgrade artagon/aitools/deeptutor",
                    reason="Homebrew manages upgrades for this DeepTutor installation.",
                )
              PYTHON

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

    exclude_newer = "2026-11-24T00:00:00Z"
    wheels_dir = buildpath/"wheels"
    system "uv", "build", "--wheel",
           "--python", python_arg,
           "--exclude-newer", exclude_newer,
           "--no-cache",
           "--out-dir", wheels_dir,
           "."

    deeptutor_whl = wheels_dir.glob("deeptutor-*.whl").fetch(0)
    system "uv", "tool", "install", deeptutor_whl,
           "--python", python_arg,
           "--exclude-newer", exclude_newer,
           "--no-cache"

    (libexec/"tools").glob("**/direct_url.json").each { |file| rm(file) }
    (libexec/"tools").glob("**/uv-receipt.toml").each { |file| rm(file) }

    os_tag = OS.mac? ? "darwin" : "linux"
    arch_tag = Hardware::CPU.arm? ? "arm64" : "x64"
    native_tag = "#{os_tag}-#{arch_tag}"
    (libexec/"tools").glob("**/prebuilds/*").each do |entry|
      name = entry.basename.to_s
      next if name == native_tag || name.start_with?("#{native_tag}.")

      entry.directory? ? rm_r(entry) : rm(entry)
    end
    (libexec/"tools").glob("**/pydevd_attach_to_process").each { |dir| rm_r(dir) if dir.directory? }

    # Normalize bundled dylib IDs (including hidden directories) to @rpath so
    # preserve_rpath prevents Mach-O header overflow during bottle relocation.
    if OS.mac?
      libexec.glob("**/*.dylib", File::FNM_DOTMATCH).each do |dylib|
        next if dylib.symlink? || !dylib.file?

        change_dylib_id dylib, "@rpath/#{dylib.basename}"
      end
    end

    prefix.install "THIRD_PARTY_NOTICES.md"

    apm_dir = pkgshare/"apm"
    (apm_dir/"skills/deeptutor-cli").install "SKILL.md"
    (apm_dir/"apm.yml").write <<~YAML
      name: deeptutor
      version: "#{version}"
      description: "Agent-native skill for configuring, managing, and using the DeepTutor CLI."
      author: HKUDS
      license: Apache-2.0
      targets:
        - agent-skills
      dependencies:
        apm: []
        mcp: []
        lsp: []
      includes:
        - skills
    YAML
    (apm_dir/"apm.lock.yaml").write <<~YAML
      lockfile_version: '1'
      dependencies: []
      deployments: []
    YAML
    pkgshare.install_symlink apm_dir/"skills" => "skills"

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `deeptutor` (`artagon/aitools/deeptutor`)

      - **Binary:** `deeptutor` (lightweight core CLI/SDK; for macOS Web UI app use `brew install --cask artagon/aitools/deeptutor`)
      - **Workspace home:** Set `DEEPTUTOR_HOME` or pass `--home <path>` (stores settings under `<DEEPTUTOR_HOME>/data/user/settings/`; prevents `./data/` in CWD)
      - **Hardening:** `serve` and launcher patched to `127.0.0.1` (`DEEPTUTOR_HOST` overrides launcher), `version_check_enabled=False`, `detect_installation()` auto-update disabled, wrapper exports `DEEPTUTOR_VERSION_CHECK_ENABLED=false`, `DO_NOT_TRACK=1`, `NEXT_TELEMETRY_DISABLED=1`, blocks `update`/`self-update`/`upgrade` (`exit 2`), and implements `--version`.
      - **Passive OpenAPM skill:** `#{opt_pkgshare}/apm` (`skills/deeptutor-cli/SKILL.md`)
      - **Upgrade:** `brew upgrade artagon/aitools/deeptutor`
    MARKDOWN

    (bin/"deeptutor").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DEEPTUTOR_VERSION_CHECK_ENABLED="${DEEPTUTOR_VERSION_CHECK_ENABLED:-false}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
      export NEXT_TELEMETRY_DISABLED="${NEXT_TELEMETRY_DISABLED:-1}"
      export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
      export PYTHONUTF8="${PYTHONUTF8:-1}"

      if [[ "$#" -eq 1 && ( "$1" = "--version" || "$1" = "-V" ) ]]; then
        exec "#{libexec}/tools/deeptutor/bin/python" -c 'from deeptutor.__version__ import __version__; print(f"deeptutor {__version__}")'
      fi

      subcmd=""
      subcmd_idx=0
      idx=0
      for arg in "$@"; do
        idx=$((idx + 1))
        case "${arg}" in
          --)
            break
            ;;
          -h | --help)
            break
            ;;
          -*)
            ;;
          update | self-update | upgrade)
            printf '%s\\n' "Error: Homebrew manages deeptutor upgrades. Run: brew upgrade artagon/aitools/deeptutor" >&2
            exit 2
            ;;
          *)
            subcmd="${arg}"
            subcmd_idx="${idx}"
            break
            ;;
        esac
      done

      if [[ "${subcmd}" = "serve" ]]; then
        has_host=0
        has_help=0
        idx=0
        for arg in "$@"; do
          idx=$((idx + 1))
          if [[ "${idx}" -le "${subcmd_idx}" ]]; then
            continue
          fi
          case "${arg}" in
            --)
              break
              ;;
            --host | --host=*)
              has_host=1
              ;;
            -h | --help)
              has_help=1
              ;;
          esac
        done
        if [[ "${has_host}" -eq 0 && "${has_help}" -eq 0 ]]; then
          args=()
          idx=0
          for arg in "$@"; do
            idx=$((idx + 1))
            args+=("${arg}")
            if [[ "${idx}" -eq "${subcmd_idx}" ]]; then
              args+=("--host" "127.0.0.1")
            fi
          done
          exec "#{libexec}/bin/deeptutor" "${args[@]}"
        fi
      fi

      exec "#{libexec}/bin/deeptutor" "$@"
    SH
    chmod 0755, bin/"deeptutor"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `deeptutor update`, `self-update`, or `upgrade`. Use:
        brew upgrade artagon/aitools/deeptutor

      This formula installs the lightweight core `deeptutor` CLI/SDK (`chat` and
      `ask_questions` capabilities plus `init`, `config`, `doctor`, `session`,
      `workspace`, `skill`, `plugin`, and `module` commands) without optional
      server/web/ML extras. For the bundled macOS desktop app with the full Web UI:
        brew install --cask artagon/aitools/deeptutor

      Hardened defaults:
        - Startup version checks are disabled (`DEEPTUTOR_VERSION_CHECK_ENABLED=false`)
        - `DO_NOT_TRACK=1` and `NEXT_TELEMETRY_DISABLED=1` are set by default
        - `deeptutor serve` binds to `127.0.0.1` by default (do not bind `--host`
          to a non-loopback address without an authenticated proxy or firewall)

      Initialize an isolated workspace explicitly with:
        deeptutor init --cli --home ~/deeptutor-workspace

      Passively staged agent skill, OpenAPM metadata, agent guide, and third-party notices:
        #{opt_pkgshare}/skills/deeptutor-cli/SKILL.md
        #{opt_pkgshare}/apm/apm.yml
        #{opt_share}/doc/deeptutor/AGENTS.md
        #{opt_prefix}/THIRD_PARTY_NOTICES.md

      This formula does not modify any agent configuration, skill, hook, or user dotfile on install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s
    workspace = testpath/"workspace"
    workspace.mkpath
    ENV["DEEPTUTOR_HOME"] = workspace.to_s

    assert_equal "deeptutor #{version}", shell_output("#{bin}/deeptutor --version").strip
    assert_match "DeepTutor CLI", shell_output("#{bin}/deeptutor --help")
    assert_match "127.0.0.1", shell_output("#{bin}/deeptutor serve --help")

    assert_match "brew upgrade artagon/aitools/deeptutor", shell_output("#{bin}/deeptutor update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/deeptutor", shell_output("#{bin}/deeptutor self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/deeptutor", shell_output("#{bin}/deeptutor upgrade 2>&1", 2)
    assert_match "DeepTutor CLI", shell_output("#{bin}/deeptutor --help update")

    probe_src = (bin/"deeptutor").read
    refute_nil probe_src.sub!(%Q(exec "#{libexec}/bin/deeptutor" "$@"), "exec /usr/bin/env")
    probe = testpath/"deeptutor-env-probe"
    probe.write(probe_src)
    chmod 0755, probe
    env_out = shell_output(
      "env -u DEEPTUTOR_VERSION_CHECK_ENABLED -u DO_NOT_TRACK -u NEXT_TELEMETRY_DISABLED #{probe} config show",
    )
    assert_match(/^DEEPTUTOR_VERSION_CHECK_ENABLED=false$/, env_out)
    assert_match(/^DO_NOT_TRACK=1$/, env_out)
    assert_match(/^NEXT_TELEMETRY_DISABLED=1$/, env_out)

    modules = JSON.parse(shell_output("#{bin}/deeptutor module list"))
    core = modules.find { |entry| entry["id"] == "core" }
    refute_nil core
    assert core["installed"]
    assert core["enabled"]
    assert core["ready"]

    providers = JSON.parse(shell_output("#{bin}/deeptutor config providers"))
    assert_kind_of Hash, providers

    shell_output("#{bin}/deeptutor init --non-interactive --home #{workspace}")
    config_show = JSON.parse(shell_output("#{bin}/deeptutor config show --home #{workspace}"))
    assert_kind_of Hash, config_show["ports"]

    hardening_check = JSON.parse(
      shell_output(
        "#{libexec}/tools/deeptutor/bin/python -c " \
        "'import json; " \
        "from deeptutor.services.app_update import detect_installation; " \
        "from deeptutor.services.config import load_system_settings; " \
        "inst = detect_installation(); " \
        "sys_cfg = load_system_settings(); " \
        "print(json.dumps({\"auto\": inst.automatic_update, \"cmd\": inst.command, " \
        "\"ver_check\": sys_cfg[\"version_check_enabled\"]}))'",
      ),
    )
    refute hardening_check["auto"]
    assert_equal "brew upgrade artagon/aitools/deeptutor", hardening_check["cmd"]
    refute hardening_check["ver_check"]

    assert_path_exists pkgshare/"skills/deeptutor-cli/SKILL.md"
    assert_match "name: deeptutor-cli", (pkgshare/"skills/deeptutor-cli/SKILL.md").read
    assert_path_exists pkgshare/"apm/apm.yml"
    assert_match "version: \"#{version}\"", (pkgshare/"apm/apm.yml").read
    assert_path_exists pkgshare/"apm/apm.lock.yaml"
    refute_predicate pkgshare/"apm/skills", :symlink?
    assert_path_exists doc/"AGENTS.md"
    assert_path_exists prefix/"THIRD_PARTY_NOTICES.md"

    %w[.claude .codex .gemini .config].each do |dotfile|
      refute_path_exists testpath/dotfile
    end
  end
end
