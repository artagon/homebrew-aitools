class PrintingPressLibrary < Formula
  desc "Catalog and installer CLI for Printing Press-generated Go CLIs and skills"
  homepage "https://printingpress.dev"
  url "https://registry.npmjs.org/@mvanhorn/printing-press-library/-/printing-press-library-0.1.27.tgz"
  sha256 "aa27d66eba987267ab603242f67e0290440b013251e5ed3e0beaf225a579087e"
  license "MIT"

  livecheck do
    url :stable
    strategy :npm
  end

  depends_on "node"

  resource "skill" do
    url "https://raw.githubusercontent.com/mvanhorn/printing-press-library/08b0f85b7a8a857a2dde2d98aa5dc41a5382c18f/skills/printing-press-library/SKILL.md"
    sha256 "c46ee782b0b2abb2193ab429054baa74c850f36659bfa79100e3a8fd008196f8"
  end

  def install
    system "npm", "install", *std_npm_args

    # Prune any foreign-OS/CPU prebuilds inside installed Node dependencies.
    os_tag = OS.mac? ? "darwin" : "linux"
    arch_tag = Hardware::CPU.arm? ? "arm64" : "x64"
    native_tag = "#{os_tag}-#{arch_tag}"
    pkg_root = libexec/"lib/node_modules/@mvanhorn/printing-press-library"
    (pkg_root/"node_modules").glob("**/prebuilds").each do |prebuilds_dir|
      next unless prebuilds_dir.directory?

      prebuilds_dir.children.each do |entry|
        name = entry.basename.to_s
        next if name == native_tag || name.start_with?("#{native_tag}.")

        entry.directory? ? rm_r(entry) : rm(entry)
      end
    end

    resource("skill").stage do
      (pkgshare/"skills/printing-press-library").install "SKILL.md"
    end

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `printing-press-library` (`artagon/aitools/printing-press-library`)

      - **Binary:** `printing-press-library`
      - **Discovery commands (read-only):** `list --json`, `search <query> --json`, `list --installed --json` (`--registry-url` overrides live catalog URL)
      - **Install targets (opt-in):** Go catalog CLIs default to `~/.local/bin` (`--bin-dir` overrides; requires `go` on `PATH`); `--cli-only` skips `npx skills`, `--skill-only` skips `go install`.
      - **Hardening:** Wrapper exports `DO_NOT_TRACK=1` and `DISABLE_TELEMETRY=1`; `update`/`reinstall` refresh catalog CLIs (not this Homebrew package).
      - **Passive skill:** `#{opt_pkgshare}/skills/printing-press-library/SKILL.md`
      - **Upgrade:** `brew upgrade artagon/aitools/printing-press-library`
    MARKDOWN

    node_bin = formula_opt_bin("node")/"node"
    cli_entry = pkg_root/"bin/printing-press-library.mjs"
    (bin/"printing-press-library").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
      export DISABLE_TELEMETRY="${DISABLE_TELEMETRY:-1}"

      exec "#{node_bin}" "#{cli_entry}" "$@"
    SH
    chmod 0755, bin/"printing-press-library"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades for `printing-press-library` itself:
        brew upgrade artagon/aitools/printing-press-library

      Note that `printing-press-library update` and `printing-press-library reinstall`
      refresh installed catalog CLIs (not this Homebrew package). Installing Go catalog
      CLIs requires `go` on `PATH` (`brew install go`) and writes binaries to
      `~/.local/bin` by default (`--bin-dir` overrides; `--cli-only` skips `npx skills`;
      `--skill-only` skips `go install`).

      The wrapper sets `DO_NOT_TRACK=1` and `DISABLE_TELEMETRY=1` by default.

      The discovery agent skill and package agent guide are staged passively under:
        #{opt_pkgshare}/skills/printing-press-library
        #{opt_share}/doc/printing-press-library/AGENTS.md

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    assert_equal version.to_s, shell_output("#{bin}/printing-press-library --version").strip
    assert_match "Printing Press Library CLI installer", shell_output("#{bin}/printing-press-library --help")

    node_bin = formula_opt_bin("node")/"node"
    cli_entry = libexec/"lib/node_modules/@mvanhorn/printing-press-library/bin/printing-press-library.mjs"
    probe_src = (bin/"printing-press-library").read
    refute_nil probe_src.sub!(%Q(exec "#{node_bin}" "#{cli_entry}" "$@"), "exec /usr/bin/env")
    probe = testpath/"ppl-env-probe"
    probe.write(probe_src)
    chmod 0755, probe

    default_env = shell_output("env -u DO_NOT_TRACK -u DISABLE_TELEMETRY #{probe}")
    assert_match(/^DO_NOT_TRACK=1$/, default_env)
    assert_match(/^DISABLE_TELEMETRY=1$/, default_env)

    port = free_port
    ready_file = testpath/"mock-registry.ready"
    server_script = testpath/"mock-registry.mjs"
    server_script.write <<~JS
      import { writeFileSync } from "node:fs";
      import http from "node:http";

      const payload = JSON.stringify({
        schema_version: 2,
        entries: [
          {
            name: "demo",
            category: "developer-tools",
            api: "Demo API",
            description: "Offline fixture CLI for Homebrew verification.",
            path: "library/developer-tools/demo",
            search_terms: ["fixture", "verification"],
          },
        ],
      });

      const server = http.createServer((_req, res) => {
        res.writeHead(200, { "content-type": "application/json" });
        res.end(payload);
      });
      server.listen(#{port}, "127.0.0.1", () => {
        writeFileSync(#{ready_file.to_s.to_json}, "ready");
      });
    JS

    pid = spawn(node_bin.to_s, server_script.to_s)
    begin
      50.times do
        break if ready_file.exist?

        sleep 0.1
      end
      assert_path_exists ready_file

      registry_url = "http://127.0.0.1:#{port}/registry.json"
      cli = "#{bin}/printing-press-library"
      listed = JSON.parse(shell_output("#{cli} list --json --registry-url #{registry_url}"))
      assert_equal ["demo"], listed.map { |entry| entry["name"] }

      found = JSON.parse(shell_output("#{cli} search fixture --json --registry-url #{registry_url}"))
      assert_equal ["demo"], found.map { |entry| entry["name"] }

      installed = JSON.parse(shell_output("#{cli} list --installed --json --registry-url #{registry_url}"))
      assert_equal [], installed

      assert_match "Refusing to uninstall without --yes",
                   shell_output("#{cli} uninstall demo --registry-url #{registry_url} 2>&1", 1)
    ensure
      begin
        Process.kill("TERM", pid)
      rescue Errno::ESRCH
        nil
      end
      begin
        Process.wait(pid)
      rescue Errno::ECHILD
        nil
      end
    end

    skill_file = pkgshare/"skills/printing-press-library/SKILL.md"
    assert_path_exists skill_file
    assert_match(/^name: printing-press-library$/, skill_file.read)
    assert_path_exists doc/"AGENTS.md"

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
