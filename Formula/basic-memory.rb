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

  depends_on "rust" => :build
  depends_on "uv" => :build

  def install
    ENV["UV_PYTHON_PREFERENCE"] = "only-managed"
    ENV["UV_PYTHON_INSTALL_DIR"] = libexec/"python"
    ENV["UV_TOOL_DIR"] = libexec/"tools"
    ENV["UV_TOOL_BIN_DIR"] = libexec/"bin"
    ENV["UV_DYNAMIC_VERSIONING_BYPASS"] = version.to_s

    # Python 3.13 is required for macOS onnxruntime/fastembed wheels.
    system "uv", "tool", "install", ".", "--python", "3.13", "--no-cache"

    (pkgshare/"skills").install Dir["skills/memory-*"]

    %w[basic-memory bm].each do |cmd|
      (bin/cmd).write <<~SH
        #!/bin/bash
        set -euo pipefail

        # Enforce local-only routing and disable auto-updates, promos, and telemetry.
        export BASIC_MEMORY_AUTO_UPDATE="false"
        export BASIC_MEMORY_NO_PROMOS="1"
        export BASIC_MEMORY_CLOUD_PROMO_OPT_OUT="true"
        export BASIC_MEMORY_FORCE_LOCAL="true"
        export BASIC_MEMORY_EXPLICIT_ROUTING="true"
        export BASIC_MEMORY_LOGFIRE_ENABLED="false"
        export BASIC_MEMORY_LOGFIRE_SEND_TO_LOGFIRE="false"

        prev=""
        for arg in "$@"; do
          if [ "$prev" = "--transport" ]; then
            case "$arg" in
              stdio) ;;
              *)
                echo "Error: basic-memory HTTP/SSE transports ('$arg') are disabled; only '--transport stdio' is permitted." >&2
                exit 2
                ;;
            esac
            prev=""
            continue
          fi
          case "$arg" in
            cloud)
              echo "Error: basic-memory cloud mode is disabled in this Homebrew build (local stdio only)." >&2
              exit 2
              ;;
            update)
              echo "Error: Homebrew manages basic-memory upgrades. Run: brew upgrade artagon/aitools/basic-memory" >&2
              exit 2
              ;;
            --transport)
              prev="--transport"
              ;;
            --transport=stdio)
              ;;
            --transport=*)
              echo "Error: basic-memory HTTP/SSE transports ('$arg') are disabled; only '--transport=stdio' is permitted." >&2
              exit 2
              ;;
          esac
        done

        exec "#{libexec}/bin/#{cmd}" "$@"
      SH
      chmod 0755, bin/cmd
    end
  end

  def post_install
    # Re-sign bundled wheel Mach-O extensions after Homebrew ruby-macho relocation on Apple Silicon.
    return unless OS.mac?
    return unless Hardware::CPU.arm?

    Dir.glob(libexec/"**/*.{so,dylib}", File::FNM_DOTMATCH).each do |file|
      next if quiet_system("codesign", "--verify", file)

      system "codesign", "--force", "--sign", "-", file
    end
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `basic-memory update` or `bm update`. Use:
        brew upgrade artagon/aitools/basic-memory

      This build enforces local stdio JSON-RPC only:
        - `cloud`, `streamable-http`, and `sse` transports are disabled
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
    assert_match "HTTP/SSE transports", shell_output("#{bin}/basic-memory mcp --transport sse 2>&1", 2)
    assert_match "HTTP/SSE transports", shell_output("#{bin}/bm mcp --transport=streamable-http 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/basic-memory", shell_output("#{bin}/bm update 2>&1", 2)

    assert_path_exists pkgshare/"skills/memory-notes/SKILL.md"
  end
end
