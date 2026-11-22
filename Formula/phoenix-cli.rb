class PhoenixCli < Formula
  desc "Command-line trace, dataset, experiment, and agent setup client for Phoenix"
  homepage "https://arize.com/docs/phoenix"
  url "https://github.com/Arize-ai/phoenix/archive/refs/tags/%40arizeai%2Fphoenix-cli%401.22.1.tar.gz"
  sha256 "0cd92adfa7f29a26a559419d83d3039fc6802d2effb1d74ad4e55d5d212bb3b8"
  license "Apache-2.0"
  head "https://github.com/Arize-ai/phoenix.git", branch: "main"

  livecheck do
    url :stable
    regex(%r{^@arizeai/phoenix-cli@v?(\d+(?:\.\d+)+)$}i)
    strategy :github_releases
  end

  depends_on "pnpm" => :build
  depends_on "node"

  conflicts_with "pixie", because: "both install `px` binaries"
  conflicts_with "px", because: "both install `px` binaries"

  def install
    ENV["COREPACK_ENABLE_STRICT"] = "0"
    ENV["PNPM_HOME"] = (buildpath/".pnpm-home").to_s

    # Disable startup banner and unknown-command npm registry version checks unless explicitly opted in.
    old_fn = <<~TS.chomp
      export async function fetchLatestPublishedCliVersion({
        fetchFn = fetch,
        timeoutMs = DEFAULT_VERSION_CHECK_TIMEOUT_MS,
      }: FetchLatestPublishedCliVersionOptions = {}): Promise<string | undefined> {
    TS
    new_fn = <<~TS.chomp
      export async function fetchLatestPublishedCliVersion({
        fetchFn = fetch,
        timeoutMs = DEFAULT_VERSION_CHECK_TIMEOUT_MS,
      }: FetchLatestPublishedCliVersionOptions = {}): Promise<string | undefined> {
        if (process.env.PHOENIX_CLI_UPDATE_CHECK !== "1") return undefined;
    TS
    inreplace "js/packages/phoenix-cli/src/version.ts", old_fn, new_fn

    # Allow Homebrew's current pnpm release without Corepack version-pin rejection.
    inreplace "js/package.json", /,\s*"packageManager":\s*"[^"]+"/, ""

    tarballs_dir = libexec/"tarballs"
    tarballs_dir.mkpath

    cd "js" do
      system "pnpm", "install", "--frozen-lockfile"
      system "pnpm", "--filter", "@arizeai/phoenix-cli...", "run", "build"
      %w[phoenix-config phoenix-otel phoenix-client phoenix-cli].each do |pkg|
        system "pnpm", "--filter", "@arizeai/#{pkg}", "pack", "--pack-destination", tarballs_dir
      end
    end

    overrides = {}
    tarballs_dir.glob("*.tgz").sort.each do |tgz|
      manifest = JSON.parse(Utils.safe_popen_read("tar", "-xOf", tgz.to_s, "package/package.json"))
      overrides[manifest.fetch("name")] = "file:./tarballs/#{tgz.basename}"
    end

    (libexec/"package.json").write JSON.pretty_generate(
      name:         "phoenix-cli-homebrew",
      private:      true,
      dependencies: { "@arizeai/phoenix-cli" => overrides.fetch("@arizeai/phoenix-cli") },
      overrides:,
    )

    cd libexec do
      system "npm", "install", *std_npm_args(prefix: false), "--omit=dev"
    end

    rm_r(tarballs_dir)
    [
      libexec/"package.json",
      libexec/"package-lock.json",
      libexec/"node_modules/.package-lock.json",
    ].each do |f|
      rm(f) if f.exist?
    end
    (libexec/"package.json").write <<~JSON
      { "private": true, "type": "module" }
    JSON

    # Prune any foreign-OS/CPU prebuilds inside installed Node dependencies.
    os_tag = OS.mac? ? "darwin" : "linux"
    arch_tag = Hardware::CPU.arm? ? "arm64" : "x64"
    native_tag = "#{os_tag}-#{arch_tag}"
    (libexec/"node_modules").glob("**/prebuilds").each do |prebuilds_dir|
      next unless prebuilds_dir.directory?

      prebuilds_dir.children.each do |entry|
        name = entry.basename.to_s
        next if name == native_tag || name.start_with?("#{native_tag}.")

        entry.directory? ? rm_r(entry) : rm(entry)
      end
    end

    (pkgshare/"skills").install Dir["skills/phoenix-*"]
    (pkgshare/"plugins").install "plugins/claude", "plugins/codex"

    node_bin = formula_opt_bin("node")/"node"
    cli_entry = libexec/"node_modules/@arizeai/phoenix-cli/build/index.js"
    pxi_entry = libexec/"node_modules/@arizeai/phoenix-cli/build/pxi/index.js"

    %w[px phoenix-cli].each do |cmd|
      (bin/cmd).write <<~SH
        #!/bin/bash
        # Target contract: macOS /bin/bash 3.2+ wrapper.
        set -euo pipefail

        export SCARF_NO_ANALYTICS="${SCARF_NO_ANALYTICS:-true}"
        export DO_NOT_TRACK="${DO_NOT_TRACK:-true}"

        seen_subcmd=0
        is_self=0
        skip_next=0
        after_ddash=0
        for arg in "$@"; do
          if [[ "${skip_next}" -eq 1 ]]; then
            skip_next=0
            continue
          fi
          if [[ "${after_ddash}" -eq 0 ]]; then
            case "${arg}" in
              --)
                after_ddash=1
                continue
                ;;
              --endpoint|--api-key|--project|--profile|--format)
                skip_next=1
                continue
                ;;
              -*)
                continue
                ;;
            esac
          fi
          if [[ "${seen_subcmd}" -eq 0 ]]; then
            seen_subcmd=1
            if [[ "${arg}" = "self" ]]; then
              is_self=1
            fi
          elif [[ "${is_self}" -eq 1 ]]; then
            if [[ "${arg}" = "update" ]]; then
              printf '%s\\n' "Error: Homebrew manages phoenix-cli upgrades. Run: brew upgrade artagon/aitools/phoenix-cli" >&2
              exit 2
            fi
            is_self=0
          fi
        done

        exec "#{node_bin}" "#{cli_entry}" "$@"
      SH
      chmod 0755, bin/cmd
    end

    (bin/"pxi").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export SCARF_NO_ANALYTICS="${SCARF_NO_ANALYTICS:-true}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-true}"

      exec "#{node_bin}" "#{pxi_entry}" "$@"
    SH
    chmod 0755, bin/"pxi"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `px self update`. Use:
        brew upgrade artagon/aitools/phoenix-cli

      Startup npm registry version checks and Scarf analytics are disabled by default.

      Bundled Phoenix coding-agent skills and plugins are installed under:
        #{opt_pkgshare}/skills
        #{opt_pkgshare}/plugins

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    assert_equal version.to_s, shell_output("#{bin}/px --version").strip
    assert_equal version.to_s, shell_output("#{bin}/phoenix-cli --version").strip
    assert_match "Phoenix", shell_output("#{bin}/pxi --help")

    assert_match "brew upgrade artagon/aitools/phoenix-cli",
                 shell_output("#{bin}/px self update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/phoenix-cli",
                 shell_output("#{bin}/px -- self update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/phoenix-cli",
                 shell_output("#{bin}/phoenix-cli self -- update --check 2>&1", 2)

    system bin/"px", "profile", "create", "local",
           "--endpoint", "http://127.0.0.1:6006",
           "--project", "eval-suite",
           "--activate"
    prof = JSON.parse(shell_output("#{bin}/px profile show --format raw"))
    assert_equal "http://127.0.0.1:6006", prof["endpoint"]

    assert_path_exists pkgshare/"skills/phoenix-cli/SKILL.md"
    assert_path_exists pkgshare/"skills/phoenix-evals/SKILL.md"
    assert_path_exists pkgshare/"plugins/claude"
    assert_path_exists pkgshare/"plugins/codex"
  end
end
