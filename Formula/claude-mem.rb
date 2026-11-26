class ClaudeMem < Formula
  desc "Persistent cross-session memory CLI and local MCP server for coding agents"
  homepage "https://github.com/thedotmack/claude-mem"
  url "https://github.com/thedotmack/claude-mem/archive/refs/tags/v17.0.0.tar.gz"
  sha256 "a0b64f4459a8c2cad5ee350ee92e7f2033d41ac00112d23dd5a37e3de8c59d7d"
  license "Apache-2.0"
  head "https://github.com/thedotmack/claude-mem.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/claude-mem-16.1.0"
    rebuild 2
    sha256               arm64_tahoe:  "bf2ba80236be040d8fe157f1886535e27495d7bcbf72e3c9f2771a90e9c8e0c5"
    sha256 cellar: :any, arm64_linux:  "4920d8b5cb0dcb038b8209e7612687a8db973c3f62b929b8dd33605314d4a0bf"
    sha256 cellar: :any, x86_64_linux: "aba9da2a7c5d5c9d2c60faa9011f480e2bd85a026489776c354240f060dc5982"
  end

  depends_on "bun"
  depends_on "node"
  depends_on "tree-sitter-cli"

  preserve_rpath

  def install
    ENV["HOME"] = (buildpath/".brew_home").to_s

    # 1. Ensure nested Vite UI install suppresses lifecycle scripts too.
    inreplace "scripts/build-viewer.js",
              "['ci', '--no-audit', '--no-fund']",
              "['ci', '--ignore-scripts', '--no-audit', '--no-fund']"

    # 2. Disable PostHog telemetry and exception autocapture by default.
    inreplace "src/services/telemetry/consent.ts" do |s|
      s.gsub! "return { enabled: true, source: 'default' };",
              "return { enabled: false, source: 'default' };"
      s.gsub! <<~TS_OLD.chomp, <<~TS_NEW.chomp
        export function isErrorTelemetryEnabled(env: NodeJS.ProcessEnv): boolean {
          const value = env.CLAUDE_MEM_TELEMETRY_ERRORS?.toLowerCase();
          if (value === '0' || value === 'false' || value === 'off') return false;
          return true;
        }
      TS_OLD
        export function isErrorTelemetryEnabled(env: NodeJS.ProcessEnv): boolean {
          const value = env.CLAUDE_MEM_TELEMETRY_ERRORS?.toLowerCase();
          return value === '1' || value === 'true' || value === 'on';
        }
      TS_NEW
    end

    inreplace "src/npx-cli/commands/telemetry.ts",
              "default: 'default (on — no opt-out recorded)',".b,
              "default: 'default (off in Homebrew build)',".b

    # 3. Disable background auto-update checks and supervisor launches by default.
    inreplace "src/shared/SettingsDefaultsManager.ts",
              "CLAUDE_MEM_AUTO_UPDATE: 'true',",
              "CLAUDE_MEM_AUTO_UPDATE: 'false',"

    # 4. Refuse unauthenticated non-loopback worker binds; fall back to loopback.
    inreplace "src/services/worker/worker-bind-host.ts", <<~TS_OLD.chomp, <<~TS_NEW.chomp
        return configuredHost;
      }
    TS_OLD
        if (!configuredHostIsLoopback && !localApiTokenSet) {
          return loopbackBindHostFor(configuredHost);
        }
        return configuredHost;
      }
    TS_NEW

    # 5. Prevent implicit hosted gateway selection and ambient vendor API-key billing.
    inreplace "src/npx-cli/installer-provider-choice.ts",
              "if (options.ide === 'grok-bot') return 'cmem';",
              "void options.ide;"

    inreplace "src/shared/EnvManager.ts",
              "if (!anthropic.some(key => env[key]) && " \
              "(process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN)) {",
              "if (process.env.CLAUDE_MEM_ALLOW_API_KEYS === '1' && !anthropic.some(key => env[key]) && " \
              "(process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN)) {"

    inreplace "src/server/runtime/create-server-service.ts" do |s|
      s.gsub! "process.env.ANTHROPIC_API_KEY ?? process.env.CLAUDE_MEM_ANTHROPIC_API_KEY",
              "process.env.CLAUDE_MEM_ANTHROPIC_API_KEY ?? " \
              "(process.env.CLAUDE_MEM_ALLOW_API_KEYS === '1' ? process.env.ANTHROPIC_API_KEY : undefined)"
      s.gsub! "process.env.GEMINI_API_KEY ?? process.env.CLAUDE_MEM_GEMINI_API_KEY",
              "process.env.CLAUDE_MEM_GEMINI_API_KEY ?? " \
              "(process.env.CLAUDE_MEM_ALLOW_API_KEYS === '1' ? process.env.GEMINI_API_KEY : undefined)"
      s.gsub! "process.env.OPENROUTER_API_KEY ?? process.env.CLAUDE_MEM_OPENROUTER_API_KEY",
              "process.env.CLAUDE_MEM_OPENROUTER_API_KEY ?? " \
              "(process.env.CLAUDE_MEM_ALLOW_API_KEYS === '1' ? process.env.OPENROUTER_API_KEY : undefined)"
    end

    # 6. Resolve packaged Homebrew plugin root without mutating ~/.claude, print help on bare
    #    invocation, block in-place update/upgrade, and avoid compiling shadow launchers or editing rc files.
    inreplace "src/npx-cli/index.ts" do |s|
      s.gsub! <<~TS_OLD.chomp, "const command = firstArg;"
        const command =
          firstArg.startsWith('-') && !HELP_OR_VERSION_FLAGS.has(firstArg)
            ? 'install'
            : firstArg;
      TS_OLD
      s.gsub! <<~TS_OLD.chomp, <<~TS_NEW.chomp
        async function main(): Promise<void> {
          // `uninstall --help` must show help, not run the uninstall.
          if (HELP_AWARE_COMMANDS.has(command) && args.slice(1).some((arg) => arg === '--help' || arg === '-h')) {
            printHelp();
            return;
          }

          switch (command) {
            case 'import': {
              const { runImportCommand } = await import('./commands/import-memory.js');
              await runImportCommand(args.slice(1));
              break;
            }
            case '':
            case 'install': {
              const { runInstallCommand } = await import('./commands/install.js');
              await runInstallCommand(parseInstallOptions(args));
              break;
            }

            case 'repair': {
              const { runRepairCommand } = await import('./commands/install.js');
              await runRepairCommand();
              break;
            }

            case 'update':
            case 'upgrade': {
              const { runInstallCommand } = await import('./commands/install.js');
              await runInstallCommand({ update: true });
              break;
            }
      TS_OLD
        async function main(): Promise<void> {
          if (HELP_AWARE_COMMANDS.has(command) && args.slice(1).some((arg) => arg === '--help' || arg === '-h')) {
            printHelp();
            return;
          }

          switch (command) {
            case 'import': {
              const { runImportCommand } = await import('./commands/import-memory.js');
              await runImportCommand(args.slice(1));
              break;
            }
            case '': {
              printHelp();
              break;
            }
            case 'install': {
              const { runInstallCommand } = await import('./commands/install.js');
              await runInstallCommand(parseInstallOptions(args));
              break;
            }

            case 'repair': {
              const { runRepairCommand } = await import('./commands/install.js');
              await runRepairCommand();
              break;
            }

            case 'update':
            case 'upgrade': {
              console.error('Error: Homebrew manages claude-mem upgrades. Run: brew upgrade artagon/aitools/claude-mem');
              process.exit(2);
            }
      TS_NEW
    end

    inreplace "src/shared/worker-utils.ts", <<~TS_OLD.chomp, <<~TS_NEW.chomp
        return selectWorkerScript(candidates);
      }
    TS_OLD
        if (roots.runningModuleFile === undefined) {
          const modDir = path.dirname(runningModuleFile());
          const pkgDir = existsSync(path.join(modDir, 'worker-service.cjs'))
            ? path.resolve(modDir, '..')
            : path.resolve(modDir, '..', '..', 'plugin');
          candidates.push({
            scriptPath: path.join(pkgDir, 'scripts', 'worker-service.cjs'),
            version: readPackageVersion(path.join(pkgDir, 'package.json')),
          });
        }
        return selectWorkerScript(candidates);
      }
    TS_NEW

    inreplace "src/launcher/claude-mem-launcher.ts", <<~TS_OLD.chomp, <<~TS_NEW.chomp
          if (existsSync(join(pluginRoot, 'scripts', 'worker-service.cjs'))) {
            return resolve(pluginRoot);
          }
        }
        return null;
      }
    TS_OLD
          if (existsSync(join(pluginRoot, 'scripts', 'worker-service.cjs'))) {
            return resolve(pluginRoot);
          }
        }
        const bundledRoot = resolve(dirname(process.argv[1] || __filename), '..');
        if (existsSync(join(bundledRoot, 'scripts', 'worker-service.cjs'))) return bundledRoot;
        return null;
      }
    TS_NEW

    inreplace "src/launcher/install-launcher.ts", <<~TS_OLD.chomp, <<~TS_NEW.chomp
      }): LauncherEnsureResult {
        const { logger, invocationContext } = options;
        const host = options.host ?? currentLauncherHostEnvironment();
    TS_OLD
      }): LauncherEnsureResult {
        const { logger, invocationContext } = options;
        const host = options.host ?? currentLauncherHostEnvironment();
        const existingOnPath = findExecutableOnPath('claude-mem', host.environmentVariables.PATH ?? '', host.platform);
        if (existingOnPath) {
          return { status: 'already-current', binaryPath: existingOnPath, pathSetupOutcome: 'already-on-path' };
        }
    TS_NEW

    inreplace "src/npx-cli/commands/doctor.ts", <<~TS_OLD.chomp.b, <<~TS_NEW.chomp.b
      export function hookLauncherCheck(
        host: LauncherHostEnvironment = currentLauncherHostEnvironment(),
        runningCliPath: string | undefined = process.argv[1],
        verifySignature: LauncherCodesignRunner = verifyLauncherSignature,
        bunVersion: string | null = null,
      ): CheckResult {
        const name = 'Hook launcher';
        const reinstallHint = 'run `npx claude-mem install`';
        const searchPath = pathWithoutRunningCli(host.environmentVariables.PATH ?? '', host.platform, runningCliPath);
        const launcherOnPath = findExecutableOnPath('claude-mem', searchPath, host.platform);
        if (!launcherOnPath) {
          const placedBinaryPath = resolveLauncherBinaryPath(host);
          return {
            name,
            status: 'fail',
            detail: existsSync(placedBinaryPath)
              ? `installed at ${placedBinaryPath} but its directory is not on PATH — open a new terminal, or ${reinstallHint}`
              : `claude-mem not on PATH — hooks fail with 'Executable not found in $PATH: "claude-mem"'; ${reinstallHint}`,
            required: true,
          };
        }
        const probeStartedAt = performance.now();
    TS_OLD
      export function hookLauncherCheck(
        host: LauncherHostEnvironment = currentLauncherHostEnvironment(),
        runningCliPath: string | undefined = process.argv[1],
        verifySignature: LauncherCodesignRunner = verifyLauncherSignature,
        bunVersion: string | null = null,
      ): CheckResult {
        const name = 'Hook launcher';
        const reinstallHint = 'run `npx claude-mem install`';
        const searchPath = pathWithoutRunningCli(host.environmentVariables.PATH ?? '', host.platform, runningCliPath);
        const launcherOnPath = findExecutableOnPath('claude-mem', searchPath, host.platform);
        if (!launcherOnPath) {
          const placedBinaryPath = resolveLauncherBinaryPath(host);
          return {
            name,
            status: 'fail',
            detail: existsSync(placedBinaryPath)
              ? `installed at ${placedBinaryPath} but its directory is not on PATH — open a new terminal, or ${reinstallHint}`
              : `claude-mem not on PATH — hooks fail with 'Executable not found in $PATH: "claude-mem"'; ${reinstallHint}`,
            required: true,
          };
        }
        if (host.environmentVariables.CLAUDE_MEM_HOMEBREW_WRAPPER === '1') {
          return { name, status: 'ok', detail: `${launcherOnPath} (Homebrew wrapper)`, required: true };
        }
        const probeStartedAt = performance.now();
    TS_NEW

    inreplace "src/servers/mcp-server.ts", <<~TS_OLD.chomp.b, <<~TS_NEW.chomp.b
      start().catch((error) => {
        logger.error('SYSTEM', 'Fatal error', undefined, error);
        process.exit(fatalExitCode);
      });
    TS_OLD
      start().catch((error) => {
        logger.error('SYSTEM', 'Fatal error', undefined, error);
        if (fatalExitCode !== 0) {
          process.stderr.write(`${error instanceof Error ? error.message : String(error)}\\n`);
        }
        process.exit(fatalExitCode);
      });
    TS_NEW

    system "npm", "install", *std_npm_args(prefix: false)
    system "node", "scripts/sync-plugin-manifests.js"
    system "node", "scripts/build-hooks.js"
    system "npm", "install", *std_npm_args
    rm_r(libexec/"bin")

    pkg_root = libexec/"lib/node_modules/claude-mem"
    plugin_root = pkg_root/"plugin"

    # Materialize frozen plugin runtime closure from plugin/bun.lock (omitting the 700 MB
    # optional server embedder; direct sharp is installed under pkg_root/node_modules).
    cd plugin_root do
      system "bun", "install", "--frozen-lockfile", "--production", "--omit=optional", "--ignore-scripts"
    end

    bun_bin_dir = formula_opt_bin("bun")
    node_bin_dir = formula_opt_bin("node")
    tree_sitter_bin_dir = formula_opt_bin("tree-sitter-cli")
    bun_bin = bun_bin_dir/"bun"
    node_bin = node_bin_dir/"node"

    ln_sf tree_sitter_bin_dir/"tree-sitter", plugin_root/"node_modules/tree-sitter-cli/tree-sitter"

    bun_ver = Utils.safe_popen_read(bun_bin, "--version").strip
    (plugin_root/".install-version").write(
      JSON.generate(version: version.to_s, installedAt: "1970-01-01T00:00:00.000Z", bun: bun_ver),
    )

    # Prune foreign-OS/CPU prebuilt Node addons (and unused N-API prebuilds in
    # tree-sitter-* grammar packages, whose upstream linux-arm64 tarballs ship
    # mislabeled x86_64 ELF binaries) so bottles hold only host-native binaries.
    os_tag = OS.mac? ? "darwin" : "linux"
    arch_tag = Hardware::CPU.arm? ? "arm64" : "x64"
    native_tag = "#{os_tag}-#{arch_tag}"
    pkg_root.glob("**/prebuilds", File::FNM_DOTMATCH).each do |prebuilds_dir|
      next if prebuilds_dir.symlink? || !prebuilds_dir.directory?

      if (prebuilds_dir.parent/"build/Release").directory? ||
         prebuilds_dir.parent.basename.to_s.start_with?("tree-sitter-")
        rm_r(prebuilds_dir)
        next
      end

      prebuilds_dir.children.each do |entry|
        name = entry.basename.to_s
        next if name == native_tag || name.start_with?("#{native_tag}.")

        entry.directory? ? rm_r(entry) : rm(entry)
      end
    end

    prefix.install "NOTICE"
    pkgshare.mkpath
    cp_r plugin_root/"skills", pkgshare/"skills"
    cp_r plugin_root/"hooks", pkgshare/"hooks"
    cp_r plugin_root/"modes", pkgshare/"modes"
    pkgshare.install_symlink plugin_root => "plugin"

    (bin/"claude-mem").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export PATH="#{bun_bin_dir}:#{node_bin_dir}:#{tree_sitter_bin_dir}:${PATH:-/usr/bin:/bin}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
      export CLAUDE_MEM_TELEMETRY="${CLAUDE_MEM_TELEMETRY:-0}"
      export CLAUDE_MEM_TELEMETRY_ERRORS="${CLAUDE_MEM_TELEMETRY_ERRORS:-0}"
      export CLAUDE_MEM_AUTO_UPDATE="${CLAUDE_MEM_AUTO_UPDATE:-false}"
      export DISABLE_AUTOUPDATER="${DISABLE_AUTOUPDATER:-1}"
      export CLAUDE_MEM_WORKER_HOST="${CLAUDE_MEM_WORKER_HOST:-127.0.0.1}"
      export CLAUDE_MEM_SERVER_HOST="${CLAUDE_MEM_SERVER_HOST:-127.0.0.1}"
      export CLAUDE_MEM_HOMEBREW_WRAPPER="1"

      seen_subcmd=0
      subcmd=""
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
              subcmd="${arg}"
              case "${arg}" in
                update|upgrade|self-update)
                  printf '%s\\n' "Error: Homebrew manages claude-mem upgrades. Run: brew upgrade artagon/aitools/claude-mem" >&2
                  exit 2
                  ;;
              esac
            fi
            ;;
        esac
      done

      if [[ "${CLAUDE_MEM_ALLOW_API_KEYS:-0}" != "1" ]]; then
        for var_name in $(compgen -v); do
          case "${var_name}" in
            CLAUDE_MEM_SERVER_API_KEY|CLAUDE_MEM_SERVER_BETA_API_KEY)
              ;;
            *_API_KEY|*_API_KEYS|ANTHROPIC_AUTH_TOKEN)
              unset "${var_name}"
              ;;
          esac
        done
      fi

      if [[ "${subcmd}" = "hook" ]]; then
        exec "#{bun_bin}" --no-install "#{plugin_root}/scripts/claude-mem-launcher.cjs" "$@"
      fi

      exec "#{node_bin}" "#{pkg_root}/dist/npx-cli/index.js" "$@"
    SH

    (bin/"claude-mem-mcp").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper; local stdio and loopback HTTP MCP server.
      set -euo pipefail

      export PATH="#{bun_bin_dir}:#{node_bin_dir}:#{tree_sitter_bin_dir}:${PATH:-/usr/bin:/bin}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
      export CLAUDE_MEM_TELEMETRY="${CLAUDE_MEM_TELEMETRY:-0}"
      export CLAUDE_MEM_TELEMETRY_ERRORS="${CLAUDE_MEM_TELEMETRY_ERRORS:-0}"
      export CLAUDE_MEM_AUTO_UPDATE="${CLAUDE_MEM_AUTO_UPDATE:-false}"
      export DISABLE_AUTOUPDATER="${DISABLE_AUTOUPDATER:-1}"
      export CLAUDE_MEM_WORKER_HOST="${CLAUDE_MEM_WORKER_HOST:-127.0.0.1}"
      export CLAUDE_MEM_SERVER_HOST="${CLAUDE_MEM_SERVER_HOST:-127.0.0.1}"
      export CLAUDE_MEM_MCP_HTTP_HOST="${CLAUDE_MEM_MCP_HTTP_HOST:-127.0.0.1}"

      for arg in "$@"; do
        case "${arg}" in
          --)
            break
            ;;
          update|upgrade|self-update)
            printf '%s\\n' "Error: Homebrew manages claude-mem upgrades. Run: brew upgrade artagon/aitools/claude-mem" >&2
            exit 2
            ;;
        esac
      done

      if [[ "${CLAUDE_MEM_ALLOW_API_KEYS:-0}" != "1" ]]; then
        for var_name in $(compgen -v); do
          case "${var_name}" in
            CLAUDE_MEM_SERVER_API_KEY|CLAUDE_MEM_SERVER_BETA_API_KEY)
              ;;
            *_API_KEY|*_API_KEYS|ANTHROPIC_AUTH_TOKEN)
              unset "${var_name}"
              ;;
          esac
        done
      fi

      exec "#{node_bin}" "#{plugin_root}/scripts/mcp-server.cjs" "$@"
    SH

    chmod 0755, [bin/"claude-mem", bin/"claude-mem-mcp"]
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `claude-mem update` or `upgrade`. Use:
        brew upgrade artagon/aitools/claude-mem

      Runtime hardening defaults in this formula:
        - PostHog telemetry, error autocapture, and background auto-updates are disabled.
        - Worker, server, and HTTP MCP endpoints bind to loopback (`127.0.0.1`) by default.
        - Observation compression defaults to local CLI subscription auth (`claude`), and
          ambient vendor `*_API_KEY` variables are scrubbed unless `CLAUDE_MEM_ALLOW_API_KEYS=1`
          is explicitly set.

      Register the local stdio MCP server with:
        #{opt_bin}/claude-mem-mcp

      Or pass the staged plugin directory to Claude Code without modifying `~/.claude`:
        claude --plugin-dir #{opt_pkgshare}/plugin

      Bundled plugin, skills, hooks, and modes are staged passively under:
        #{opt_pkgshare}/plugin
        #{opt_pkgshare}/skills
        #{opt_pkgshare}/hooks
        #{opt_pkgshare}/modes

      This formula does not modify any agent configuration file or shell profile during install.
    EOS
  end

  test do
    require "open3"
    require "timeout"

    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["CLAUDE_MEM_WORKER_AUTOSTART"] = "false"

    assert_equal version.to_s, shell_output("#{bin}/claude-mem --version").strip
    assert_match "Install Commands", shell_output("#{bin}/claude-mem")

    assert_match "brew upgrade artagon/aitools/claude-mem",
                 shell_output("#{bin}/claude-mem update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/claude-mem",
                 shell_output("#{bin}/claude-mem upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/claude-mem",
                 shell_output("#{bin}/claude-mem self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/claude-mem",
                 shell_output("#{bin}/claude-mem-mcp update 2>&1", 2)

    assert_match "DISABLED", shell_output("#{bin}/claude-mem telemetry status")

    doctor_out = shell_output("#{bin}/claude-mem doctor")
    assert_match "CLAUDE_MEM_AUTO_UPDATE=false", doctor_out
    assert_match "All required checks passed.", doctor_out

    assert_match "Refusing to listen on 0.0.0.0",
                 shell_output("#{bin}/claude-mem-mcp --http --host 0.0.0.0 2>&1", 1)

    (testpath/"sample.ts").write <<~TS
      export function verifyProvenanceDigest(digest: string): boolean {
        return digest.length === 64;
      }
    TS

    requests = [
      { jsonrpc: "2.0", id: 1, method: "initialize",
        params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "brew", version: "1" } } },
      { jsonrpc: "2.0", method: "notifications/initialized" },
      { jsonrpc: "2.0", id: 2, method: "tools/list" },
      { jsonrpc: "2.0", id: 3, method: "tools/call",
        params: { name: "smart_outline", arguments: { file_path: (testpath/"sample.ts").to_s } } },
    ]

    lines = []
    Open3.popen3(bin/"claude-mem-mcp") do |stdin, stdout, _stderr, wait_thr|
      requests.each { |req| stdin.puts(JSON.generate(req)) }
      stdin.flush
      Timeout.timeout(15) do
        lines << stdout.gets while lines.length < 3
      end
      stdin.close
      assert_predicate wait_thr.value, :success?
    end
    mcp_out = lines.compact.join
    assert_match '"name":"search"', mcp_out
    assert_match '"name":"smart_outline"', mcp_out
    assert_match "verifyProvenanceDigest", mcp_out

    assert_path_exists prefix/"NOTICE"
    assert_path_exists pkgshare/"skills/mem-search/SKILL.md"
    assert_path_exists pkgshare/"plugin/scripts/mcp-server.cjs"
    refute_path_exists testpath/".claude"
  end
end
