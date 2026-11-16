class BasicMemory < Formula
  desc "Local-first knowledge graph and stdio MCP server for AI agents"
  homepage "https://github.com/basicmachines-co/basic-memory"
  url "https://github.com/basicmachines-co/basic-memory/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "712c6e19fe6b05da6db706d22bb92436486a789805d2202dee1c32cfc688391a"
  license "AGPL-3.0-or-later"
  head "https://github.com/basicmachines-co/basic-memory.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "uv" => :build

  preserve_rpath

  def install
    ENV["UV_PYTHON_PREFERENCE"] = "only-managed"
    ENV["UV_PYTHON_INSTALL_DIR"] = libexec/"python"
    ENV["UV_TOOL_DIR"] = libexec/"tools"
    ENV["UV_TOOL_BIN_DIR"] = libexec/"bin"
    ENV["UV_DYNAMIC_VERSIONING_BYPASS"] = version.to_s

    # Python 3.13 is required for macOS onnxruntime/fastembed wheels.
    system "uv", "tool", "install", ".", "--python", "3.13", "--no-cache"

    # Set @rpath dylib IDs on bundled wheel dylibs (e.g. Pillow's PIL/.dylibs) so
    # preserve_rpath prevents Mach-O header overflow during bottle relocation.
    if OS.mac?
      libexec.glob("**/*.dylib", File::FNM_DOTMATCH).each do |dylib|
        next if dylib.symlink? || !dylib.file?

        change_dylib_id dylib, "@rpath/#{dylib.basename}"
      end
    end

    (pkgshare/"skills").install Dir["skills/memory-*"]

    %w[basic-memory bm].each do |cmd|
      (bin/cmd).write <<~SH
        #!/bin/bash
        # Target contract: macOS /bin/bash 3.2+ wrapper; local stdio JSON-RPC only.
        set -euo pipefail

        export BASIC_MEMORY_AUTO_UPDATE="false"
        export BASIC_MEMORY_NO_PROMOS="1"
        export BASIC_MEMORY_CLOUD_PROMO_OPT_OUT="true"
        export BASIC_MEMORY_FORCE_LOCAL="true"
        export BASIC_MEMORY_EXPLICIT_ROUTING="true"
        export BASIC_MEMORY_LOGFIRE_ENABLED="false"
        export BASIC_MEMORY_LOGFIRE_SEND_TO_LOGFIRE="false"

        expect_val=""
        seen_subcmd=0
        for arg in "$@"; do
          if [[ "${expect_val}" = "--transport" ]]; then
            if [[ "${arg}" != "stdio" ]]; then
              printf "Error: basic-memory HTTP/SSE transports ('%s') are disabled; only '--transport stdio' is permitted.\\n" "${arg}" >&2
              exit 2
            fi
            expect_val=""
            continue
          elif [[ -n "${expect_val}" ]]; then
            expect_val=""
            continue
          fi

          case "${arg}" in
            --)
              break
              ;;
            --cloud | --cloud=*)
              printf '%s\\n' "Error: basic-memory cloud routing ('--cloud') is disabled in this Homebrew build (local stdio only)." >&2
              exit 2
              ;;
            --transport)
              expect_val="--transport"
              ;;
            --transport=stdio)
              ;;
            --transport=*)
              printf "Error: basic-memory HTTP/SSE transports ('%s') are disabled; only '--transport=stdio' is permitted.\\n" "${arg}" >&2
              exit 2
              ;;
            -p | --project | --config)
              if [[ "${seen_subcmd}" -eq 0 ]]; then
                expect_val="${arg}"
              fi
              ;;
            -*)
              ;;
            *)
              if [[ "${seen_subcmd}" -eq 0 ]]; then
                seen_subcmd=1
                case "${arg}" in
                  cloud)
                    printf '%s\\n' "Error: basic-memory cloud mode is disabled in this Homebrew build (local stdio only)." >&2
                    exit 2
                    ;;
                  update)
                    printf '%s\\n' "Error: Homebrew manages basic-memory upgrades. Run: brew upgrade artagon/aitools/basic-memory" >&2
                    exit 2
                    ;;
                esac
              fi
              ;;
          esac
        done

        exec "#{libexec}/bin/#{cmd}" "$@"
      SH
      chmod 0755, bin/cmd
    end
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `basic-memory update` or `bm update`. Use:
        brew upgrade artagon/aitools/basic-memory

      This build enforces local stdio JSON-RPC only:
        - `cloud`, `--cloud`, `streamable-http`, and `sse` transports are disabled
        - startup auto-updates, promos, and telemetry are disabled

      Register the stdio MCP server with:
        #{opt_bin}/basic-memory mcp

      Bundled agent skills are installed under:
        #{opt_pkgshare}/skills

      This formula does not modify any agent configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["BASIC_MEMORY_CONFIG_DIR"] = (testpath/".basic-memory").to_s
    ENV["BASIC_MEMORY_HOME"] = (testpath/"notes").to_s

    assert_match version.to_s, shell_output("#{bin}/basic-memory --version")
    assert_match version.to_s, shell_output("#{bin}/bm --version")

    assert_match "cloud mode is disabled", shell_output("#{bin}/basic-memory cloud login 2>&1", 2)
    assert_match "cloud routing ('--cloud') is disabled", shell_output("#{bin}/bm status --cloud 2>&1", 2)
    assert_match "HTTP/SSE transports", shell_output("#{bin}/basic-memory mcp --transport sse 2>&1", 2)
    assert_match "HTTP/SSE transports", shell_output("#{bin}/bm mcp --transport=streamable-http 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/basic-memory", shell_output("#{bin}/bm update 2>&1", 2)

    # Positional arguments named "cloud" or "update" on local commands must NOT be blocked by the wrapper.
    (testpath/"notes").mkpath
    (testpath/"notes/design.md").write("# Architecture\nLocal notes mentioning cloud and update terms.\n")
    refute_match "disabled in this Homebrew build", shell_output("#{bin}/bm tool search-notes cloud 2>&1 || true")

    requests = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"brew","version":"1"}}}
    JSON
    assert_match "protocolVersion", pipe_output("#{bin}/basic-memory mcp", requests, 0)

    assert_path_exists pkgshare/"skills/memory-notes/SKILL.md"
  end
end
