class Autoswarm < Formula
  desc "Coordinate installed coding agents from one conversation"
  homepage "https://github.com/HKUDS/AutoSwarm"
  url "https://github.com/HKUDS/AutoSwarm/archive/refs/tags/desk-v0.1.1.tar.gz"
  sha256 "da40aef34f65c9a0794bd90d5f88cc58cc43d4fa1d254333a160bea038110d9f"
  license "MIT"
  head "https://github.com/HKUDS/AutoSwarm.git", branch: "main"

  livecheck do
    url :stable
    regex(/^(?:autoswarm[._-]|desk[._-])?v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  depends_on "uv" => :build

  on_linux do
    depends_on "python@3.13"
  end

  preserve_rpath

  def install
    # Use AUTOSWARM_LAUNCHER_PYTHON (pointing at stable opt_libexec) for installed
    # host skill/hook/plugin launchers so they survive `brew upgrade` without baking
    # Homebrew prefixes into installed Python modules or bytecode.
    inreplace "src/autoswarm/setup.py" do |s|
      s.gsub!(
        "    launcher.write_text(",
        [
          '    launcher_py = os.environ.get("AUTOSWARM_LAUNCHER_PYTHON") or sys.executable',
          "    launcher.write_text(",
        ].join("\n"),
      )
      s.gsub!(
        "os.environ.setdefault('AUTOSWARM_HOME', \" + repr(str(records.home)) + \")\\n" \
        "from autoswarm.cli import main",
        "os.environ.setdefault('AUTOSWARM_HOME', \" + repr(str(records.home)) + \")\\n" \
        "os.environ.setdefault('AUTOSWARM_LAUNCHER_PYTHON', \" + repr(launcher_py) + \")\\n" \
        "from autoswarm.cli import main",
      )
      s.gsub!(
        '    argv = [sys.executable, str(launcher), "--home", str(records.home)]',
        '    argv = [launcher_py, str(launcher), "--home", str(records.home)]',
      )
    end

    rm(".python-version") if File.exist?(".python-version")

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

    exclude_newer = "2026-11-20T00:00:00Z"
    wheels_dir = buildpath/"wheels"
    system "uv", "build", "--wheel",
           "--python", python_arg,
           "--exclude-newer", exclude_newer,
           "--no-cache",
           "--out-dir", wheels_dir,
           "."

    autoswarm_whl = wheels_dir.glob("autoswarm-*.whl").fetch(0)
    system "uv", "tool", "install", autoswarm_whl,
           "--python", python_arg,
           "--exclude-newer", exclude_newer,
           "--no-cache"

    (libexec/"tools").glob("**/direct_url.json").each { |file| rm(file) }
    uv_receipt = libexec/"tools/autoswarm/uv-receipt.toml"
    rm(uv_receipt) if uv_receipt.exist?

    # Normalize bundled dylib IDs (including hidden directories) to @rpath so
    # preserve_rpath prevents Mach-O header overflow during bottle relocation.
    if OS.mac?
      libexec.glob("**/*.dylib", File::FNM_DOTMATCH).each do |dylib|
        next if dylib.symlink? || !dylib.file?

        change_dylib_id dylib, "@rpath/#{dylib.basename}"
      end
    end

    (pkgshare/"skills/autoswarm").install "src/autoswarm/assets/references"
    skill_template = (buildpath/"src/autoswarm/assets/skill-template.md").read.chomp
    launcher_json = JSON.generate(["#{opt_bin}/autoswarm"])
    (pkgshare/"skills/autoswarm/SKILL.md").write(
      "#{skill_template}\n\n" \
      "Installed launcher argv (append CLI arguments; preserve each argv entry):\n\n" \
      "```json\n#{launcher_json}\n```\n",
    )
    (pkgshare/"plugins/opencode").install "src/autoswarm/assets/opencode.js"
    doc.install "docs/architecture.md"

    (bin/"autoswarm").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export AUTOSWARM_LAUNCHER_PYTHON="${AUTOSWARM_LAUNCHER_PYTHON:-#{opt_libexec}/tools/autoswarm/bin/python}"
      export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
      export PYTHONUTF8="${PYTHONUTF8:-1}"

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
          --home | --controller)
            skip_next=1
            ;;
          --home=* | --controller=*)
            ;;
          -*)
            ;;
          update | self-update | upgrade)
            printf '%s\\n' "Error: Homebrew manages autoswarm upgrades. Run: brew upgrade artagon/aitools/autoswarm" >&2
            exit 2
            ;;
          *)
            break
            ;;
        esac
      done

      exec "#{libexec}/bin/autoswarm" "$@"
    SH
    chmod 0755, bin/"autoswarm"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `autoswarm update`, `self-update`, or `upgrade`. Use:
        brew upgrade artagon/aitools/autoswarm

      Host integrations are opt-in and are not activated during install.
      To register a host skill and integration explicitly, run:
        autoswarm setup --host <host>
      (for example: `codex`, `claude-code`, `opencode`, `cursor`, `copilot`, `kimi`, `grok`, or `hermes`).

      Reference skill files and the OpenCode plugin template are staged under:
        #{opt_pkgshare}/skills/autoswarm
        #{opt_pkgshare}/plugins/opencode

      This formula does not modify any agent configuration, skill, hook, or plugin file on install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s
    ENV["AUTOSWARM_HOME"] = (testpath/"home").to_s

    assert_match(/^AutoSwarm\s+\S+/, shell_output("#{bin}/autoswarm --version"))

    assert_match "brew upgrade artagon/aitools/autoswarm", shell_output("#{bin}/autoswarm update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/autoswarm", shell_output("#{bin}/autoswarm self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/autoswarm", shell_output("#{bin}/autoswarm upgrade 2>&1", 2)

    # Positional flag values named "update" must not be blocked by the wrapper.
    positional_out = JSON.parse(shell_output("#{bin}/autoswarm --home update agents"))
    assert positional_out["ok"]
    assert_equal (testpath.realpath/"update").to_s, positional_out.dig("data", "home")

    agents_out = JSON.parse(shell_output("#{bin}/autoswarm agents"))
    assert agents_out["ok"]
    assert_kind_of Array, agents_out.dig("data", "agents")
    assert_equal (testpath.realpath/"home").to_s, agents_out.dig("data", "home")

    desk_out = JSON.parse(shell_output("#{bin}/autoswarm desk init"))
    assert desk_out["ok"]
    assert_match(/^main_[a-f0-9]{32}$/, desk_out.dig("data", "controller_id"))

    config_out = JSON.parse(shell_output("#{bin}/autoswarm config"))
    assert config_out["ok"]
    assert config_out.dig("data", "delegate_approvals")

    expected_python = (opt_libexec/"tools/autoswarm/bin/python").to_s

    codex_skill = testpath/"skills/codex/autoswarm"
    codex_out = JSON.parse(
      shell_output("#{bin}/autoswarm setup --host codex --skill-dir #{codex_skill} --no-agents"),
    )
    assert codex_out["ok"]
    launcher = codex_out.dig("data", "launcher")
    assert_equal expected_python, launcher[0]
    assert_path_exists codex_skill/"SKILL.md"
    assert_path_exists codex_skill/"references/setup.md"
    assert_match expected_python, (codex_skill/"SKILL.md").read
    assert_match "AUTOSWARM_LAUNCHER_PYTHON", (codex_skill/"scripts/launch.py").read

    assert_match(/^AutoSwarm\s+\S+/, Utils.safe_popen_read(*launcher, "--version"))

    claude_skill = testpath/"skills/claude/autoswarm"
    claude_settings = testpath/"claude/settings.json"
    claude_out = JSON.parse(
      shell_output(
        "#{bin}/autoswarm setup --host claude-code " \
        "--skill-dir #{claude_skill} --settings-file #{claude_settings} --no-agents",
      ),
    )
    assert claude_out["ok"]
    assert_equal expected_python, claude_out.dig("data", "launcher", 0)
    assert_path_exists claude_settings
    settings_json = JSON.parse(claude_settings.read)
    assert_equal expected_python, settings_json.dig("hooks", "SessionStart", 0, "hooks", 0, "command")

    opencode_skill = testpath/"skills/opencode/autoswarm"
    opencode_plugins = testpath/"opencode/plugins"
    opencode_out = JSON.parse(
      shell_output(
        "#{bin}/autoswarm setup --host opencode " \
        "--skill-dir #{opencode_skill} --plugin-dir #{opencode_plugins} --no-agents",
      ),
    )
    assert opencode_out["ok"]
    assert_equal expected_python, opencode_out.dig("data", "launcher", 0)
    assert_path_exists opencode_plugins/"autoswarm.js"
    assert_match expected_python, (opencode_plugins/"autoswarm.js").read

    assert_path_exists pkgshare/"skills/autoswarm/SKILL.md"
    assert_match((opt_bin/"autoswarm").to_s, (pkgshare/"skills/autoswarm/SKILL.md").read)
    assert_path_exists pkgshare/"skills/autoswarm/references/setup.md"
    assert_path_exists pkgshare/"plugins/opencode/opencode.js"
    assert_path_exists doc/"architecture.md"
  end
end
