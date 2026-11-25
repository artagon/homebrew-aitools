class Paperclip < Formula
  desc "Open-source orchestration platform and CLI for teams of AI agents"
  homepage "https://paperclip.ing"
  url "https://registry.npmjs.org/paperclipai/-/paperclipai-2026.1117.0.tgz"
  sha256 "1e4600b2c6b0ae360a152cac0be734122e2b6a00bed633db93b9eae990adc6fc"
  license "MIT"

  livecheck do
    url :stable
    strategy :npm
  end

  depends_on "node"

  preserve_rpath

  def install
    system "npm", "install", *std_npm_args
    rm_r(libexec/"bin") if (libexec/"bin").exist?

    pkg_root = libexec/"lib/node_modules/paperclipai"
    nm = pkg_root/"node_modules"
    server_root = nm/"@paperclipai/server"
    server_nm = server_root/"node_modules"

    # Promote @paperclipai/server's pinned Codex and Claude Agent SDK packages up to
    # top-level node_modules so npm's semver mismatch does not ship duplicate ~500 MB copies.
    %w[@openai @anthropic-ai].each do |scope|
      src_scope = server_nm/scope
      dst_scope = nm/scope
      next if !src_scope.directory? || !dst_scope.directory?

      src_scope.children.each do |entry|
        name = entry.basename.to_s
        next unless name.start_with?("codex", "claude-agent-sdk")

        dest = dst_scope/name
        rm_r(dest) if dest.exist?
        mv entry, dest
      end
      rmdir src_scope if src_scope.empty?
    end

    node_bin_dir = formula_opt_bin("node")
    node_bin = node_bin_dir/"node"
    os_tag = OS.mac? ? "darwin" : "linux"
    arch_tag = Hardware::CPU.arm? ? "arm64" : "x64"
    native_tag = "#{os_tag}-#{arch_tag}"

    # Hydrate @embedded-postgres/<os>-<arch> relative library symlinks (skipped by --ignore-scripts).
    epg_pkg = nm/"@embedded-postgres/#{native_tag}"
    if (epg_pkg/"scripts/hydrate-symlinks.js").exist?
      cd epg_pkg do
        system node_bin, "scripts/hydrate-symlinks.js"
      end
    end

    # Retain only the host platform's native paperclip-runnerd binary and release manifest.
    runner_bin_dir = server_root/"dist/vendor/paperclip-runner/bin"
    if runner_bin_dir.directory?
      runner_bin_dir.children.each do |entry|
        name = entry.basename.to_s
        next if name == native_tag || name == "release-manifest.json"

        entry.directory? ? rm_r(entry) : rm(entry)
      end
      runnerd = runner_bin_dir/"#{native_tag}/paperclip-runnerd"
      chmod 0755, runnerd if runnerd.exist?
    end

    # Prune Bare mobile-runtime prebuilds (unused under Node.js) and any foreign OS/CPU prebuilds.
    pkg_root.glob("**/prebuilds", File::FNM_DOTMATCH).each do |prebuilds_dir|
      next if prebuilds_dir.symlink? || !prebuilds_dir.directory?

      if prebuilds_dir.parent.basename.to_s.start_with?("bare-") ||
         (prebuilds_dir.parent/"build/Release").directory?
        rm_r(prebuilds_dir)
        next
      end

      prebuilds_dir.children.each do |entry|
        name = entry.basename.to_s
        next if name == native_tag || name.start_with?("#{native_tag}.")

        entry.directory? ? rm_r(entry) : rm(entry)
      end
    end

    # Remove Windows Pageant helper binary.
    rm(nm/"ssh2/util/pagent.exe") if (nm/"ssh2/util/pagent.exe").exist?

    # Remove optional PostgreSQL extensions, PGXS regression test binaries (which lack
    # $ORIGIN RPATH and link host libpq.so.5 on Linux), and OAuth client modules linking
    # absent host libraries (Perl/Python/Tcl, pgxml -> libxslt, libpq-oauth -> libcurl).
    pg_lib_dir = epg_pkg/"native/lib"
    pg_lib_dir.glob("libpq-oauth*").each { |entry| rm(entry) } if pg_lib_dir.directory?
    pg_ext_dir = pg_lib_dir/"postgresql"
    if pg_ext_dir.directory?
      rm_r(pg_ext_dir/"pgxs") if (pg_ext_dir/"pgxs").directory?
      pg_ext_dir.children.each do |entry|
        rm(entry) if entry.basename.to_s.match?(/plperl|plpython|pltcl|pgxml/)
      end
    end

    # On x64, Paperclip pins the portable *-baseline OpenCode build; drop the duplicate AVX2 copy.
    opencode_dup = nm/"opencode-#{native_tag}"
    if !Hardware::CPU.arm? && (nm/"opencode-#{native_tag}-baseline").directory? && opencode_dup.directory?
      rm_r(opencode_dup)
    end

    # On Linux, Codex's optional bundled zsh links Debian-versioned system libtinfo.so.6
    # (not in Homebrew's Linux system-library allowlist); Codex falls back to host sh/bash/zsh.
    if OS.linux?
      pkg_root.glob("**/codex-resources/zsh", File::FNM_DOTMATCH).each do |zsh_dir|
        rm_r(zsh_dir) if zsh_dir.directory?
      end
    end

    # Prune source maps to keep bottle archives compact.
    pkg_root.glob("**/*.map", File::FNM_DOTMATCH).each do |map_file|
      rm(map_file) if map_file.file? && !map_file.symlink?
    end

    if OS.mac?
      # Thin universal Mach-O binaries in @embedded-postgres to the host slice and
      # normalize non-@rpath dylib IDs so bottle relocation cannot overflow Mach-O headers.
      universal = Keg.new(prefix).mach_o_files.select do |file|
        file.arch == :universal && file.archs.include?(Hardware::CPU.arch)
      end
      deuniversalize_machos(*universal) unless universal.empty?

      pkg_root.glob("**/*.{dylib,node,so}", File::FNM_DOTMATCH).each do |macho|
        next if macho.symlink? || !macho.file?

        wrapped = MachOPathname.wrap(macho)
        next unless wrapped.dylib?

        dylib_id = wrapped.dylib_id
        next if dylib_id.nil? || dylib_id.start_with?("@rpath/")

        change_dylib_id macho, "@rpath/#{macho.basename}"
      end
    end

    pkgshare.mkpath
    cp_r server_root/"skills", pkgshare/"skills" if (server_root/"skills").directory?

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `paperclip` (`artagon/aitools/paperclip`)

      - **Binary:** `paperclipai` (Node server, React UI, embedded PostgreSQL 18, `paperclip-runnerd`)
      - **Instance home:** `~/.paperclip/instances/default/` (`PAPERCLIP_HOME`, `PAPERCLIP_INSTANCE_ID`, `PAPERCLIP_CONFIG`)
      - **Defaults:** Loopback `127.0.0.1:3100` (`PAPERCLIP_BIND`, `HOST`, `PORT`), embedded PostgreSQL on `:54329` (`DATABASE_URL` overrides)
      - **Hardening:** Wrapper unconditionally forces `PAPERCLIP_TELEMETRY_DISABLED=1`, `DO_NOT_TRACK=1`, and `PAPERCLIP_UPDATE_CHECK=0`, defaults `PAPERCLIP_ANNOUNCEMENTS_ENABLED=false`, and blocks `update`, `upgrade`, `self-update`, `install`, and `uninstall` (`exit 2`).
      - **Passive skills:** `#{opt_pkgshare}/skills` (9 skills; zero live dotfile writes on install)
      - **Upgrade:** `brew upgrade artagon/aitools/paperclip`
    MARKDOWN

    (bin/"paperclipai").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export PATH="#{node_bin_dir}:${PATH:-/usr/bin:/bin}"
      export PAPERCLIP_TELEMETRY_DISABLED=1
      export DO_NOT_TRACK=1
      export PAPERCLIP_UPDATE_CHECK=0
      export PAPERCLIP_ANNOUNCEMENTS_ENABLED="${PAPERCLIP_ANNOUNCEMENTS_ENABLED:-false}"

      if [[ "$#" -gt 0 ]]; then
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
              -h | --help | -V | --version)
                break
                ;;
              -d | --data-dir | -c | --config | -i | --instance)
                skip_next=1
                continue
                ;;
              -*)
                continue
                ;;
            esac
          fi
          case "${arg}" in
            update | upgrade | self-update | install | uninstall)
              printf '%s\\n' "Error: Homebrew manages paperclipai upgrades. Run: brew upgrade artagon/aitools/paperclip" >&2
              exit 2
              ;;
          esac
          break
        done
      fi

      exec "#{node_bin}" "#{pkg_root}/dist/index.js" "$@"
    SH
    chmod 0755, bin/"paperclipai"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `paperclipai update`, `upgrade`, `install`,
      or `uninstall`. Use:
        brew upgrade artagon/aitools/paperclip

      Runtime hardening defaults in this formula:
        - The `paperclipai` wrapper unconditionally enforces:
            PAPERCLIP_TELEMETRY_DISABLED=1
            DO_NOT_TRACK=1
            PAPERCLIP_UPDATE_CHECK=0
          disabling usage telemetry and startup npm registry update checks.
        - Remote announcement feed fetches are disabled by default
          (`PAPERCLIP_ANNOUNCEMENTS_ENABLED=false`).
        - Local server onboarding and runtime default to loopback (`127.0.0.1:3100`);
          pass `--bind lan` / `--bind tailnet` or set `PAPERCLIP_BIND` / `HOST` to override.

      Bundled Paperclip agent skills and package agent guide are staged passively under:
        #{opt_pkgshare}/skills
        #{opt_share}/doc/paperclip/AGENTS.md

      Note: The upstream `paperclipai` npm package bundles third-party adapter SDKs
      (including `@anthropic-ai/claude-agent-sdk` and `@openai/codex`) under their
      respective upstream terms.

      This formula does not modify any agent configuration file or shell profile during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s

    pkg_root = libexec/"lib/node_modules/paperclipai"
    node_bin = formula_opt_bin("node")/"node"

    # Verify wrapper unconditionally enforces telemetry & update-check disable vars
    # even when caller overrides them to re-enable.
    probe_src = (bin/"paperclipai").read
    refute_nil probe_src.sub!(%Q(exec "#{node_bin}" "#{pkg_root}/dist/index.js" "$@"), "exec /usr/bin/env")
    probe = testpath/"paperclipai-env-probe"
    probe.write(probe_src)
    chmod 0755, probe

    override_env = {
      "PAPERCLIP_TELEMETRY_DISABLED" => "0",
      "DO_NOT_TRACK"                 => "0",
      "PAPERCLIP_UPDATE_CHECK"       => "1",
      "CI"                           => nil,
      "CONTINUOUS_INTEGRATION"       => nil,
      "BUILD_NUMBER"                 => nil,
      "GITHUB_ACTIONS"               => nil,
      "GITLAB_CI"                    => nil,
    }
    with_env(override_env) do
      child_env = shell_output(probe.to_s)
      assert_match(/^PAPERCLIP_TELEMETRY_DISABLED=1$/, child_env)
      assert_match(/^DO_NOT_TRACK=1$/, child_env)
      assert_match(/^PAPERCLIP_UPDATE_CHECK=0$/, child_env)
      assert_match(/^PAPERCLIP_ANNOUNCEMENTS_ENABLED=false$/, child_env)
    end

    assert_equal version.to_s, shell_output("#{bin}/paperclipai --version").strip
    assert_match "Paperclip CLI", shell_output("#{bin}/paperclipai --help")
    assert_match "PORT='3100'", shell_output("#{bin}/paperclipai env")

    # Verify in-place self-updaters and shadow installers are blocked with exit 2 while help/normal subcommands pass.
    assert_match "brew upgrade artagon/aitools/paperclip",
                 shell_output("#{bin}/paperclipai update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/paperclip",
                 shell_output("#{bin}/paperclipai upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/paperclip",
                 shell_output("#{bin}/paperclipai self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/paperclip",
                 shell_output("#{bin}/paperclipai install 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/paperclip",
                 shell_output("#{bin}/paperclipai uninstall 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/paperclip",
                 shell_output("#{bin}/paperclipai --data-dir #{testpath}/data update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/paperclip",
                 shell_output("#{bin}/paperclipai -- update --check 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/paperclip",
                 shell_output("#{bin}/paperclipai -- upgrade 2>&1", 2)
    assert_match "Paperclip CLI",
                 shell_output("#{bin}/paperclipai -h update")
    assert_match "Check, update, or roll back",
                 shell_output("#{bin}/paperclipai help update")

    # Verify @paperclipai/shared telemetry resolver and @paperclipai/server config defaults
    # under wrapper-enforced env (telemetry disabled, loopback 127.0.0.1, announcements off).
    verify_js = testpath/"verify-runtime.mjs"
    verify_js.write <<~JS
      import { resolveTelemetryConfig } from "#{pkg_root}/node_modules/@paperclipai/shared/dist/telemetry/index.js";
      import { loadConfig } from "#{pkg_root}/node_modules/@paperclipai/server/dist/config.js";

      const telemetry = resolveTelemetryConfig({ enabled: true });
      const config = loadConfig(null);
      console.log(JSON.stringify({
        telemetryEnabled: telemetry.enabled,
        bind: config.bind,
        host: config.host,
        port: config.port,
        announcementsEnabled: config.announcementsEnabled,
      }));
    JS
    runtime_probe = probe_src.sub("exec /usr/bin/env", %Q(exec "#{node_bin}" "#{verify_js}"))
    runtime_runner = testpath/"paperclipai-runtime-probe"
    runtime_runner.write(runtime_probe)
    chmod 0755, runtime_runner

    with_env(override_env) do
      runtime = JSON.parse(shell_output(runtime_runner.to_s))
      refute runtime["telemetryEnabled"]
      assert_equal "loopback", runtime["bind"]
      assert_equal "127.0.0.1", runtime["host"]
      assert_equal 3100, runtime["port"]
      refute runtime["announcementsEnabled"]
    end

    # Verify hydrated embedded-postgres binary & host-native paperclip-runnerd execute cleanly.
    os_tag = OS.mac? ? "darwin" : "linux"
    arch_tag = Hardware::CPU.arm? ? "arm64" : "x64"
    native_tag = "#{os_tag}-#{arch_tag}"
    server_root = pkg_root/"node_modules/@paperclipai/server"
    pg_bin = pkg_root/"node_modules/@embedded-postgres/#{native_tag}/native/bin/postgres"
    assert_match "postgres (PostgreSQL)", shell_output("#{pg_bin} --version")
    runnerd = server_root/"dist/vendor/paperclip-runner/bin/#{native_tag}/paperclip-runnerd"
    assert_match "--run-id", shell_output("#{runnerd} --version 2>&1", 1)

    assert_path_exists server_root/"ui-dist/index.html"
    assert_path_exists pkgshare/"skills/paperclip/SKILL.md"
    assert_path_exists pkgshare/"skills/paperclip-board/SKILL.md"
    assert_path_exists pkgshare/"skills/paperclip-create-agent/SKILL.md"
    assert_path_exists doc/"AGENTS.md"
    assert_path_exists prefix/"LICENSE"
    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
    refute_path_exists testpath/".paperclip/instances/default/telemetry"
  end
end
