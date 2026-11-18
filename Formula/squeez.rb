class Squeez < Formula
  desc "Token compressor and stdio MCP server for AI coding agents"
  homepage "https://github.com/claudioemmanuel/squeez"
  url "https://github.com/claudioemmanuel/squeez/archive/refs/tags/v1.49.3.tar.gz"
  sha256 "1fc60e2b46a96b0deb8ae9537beeddd1d68a2ace75efba56bb93a5d3c521e74d"
  license "Apache-2.0"
  head "https://github.com/claudioemmanuel/squeez.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build

  def install
    # Enforce conservative out-of-the-box and `squeez setup` defaults without modifying
    # live user config during formula install:
    # persona=off, auto_compress_md=false, and wrap_bash=false.
    inreplace "src/commands/persona.rs", "Persona::Ultra\n    }", "Persona::Off\n    }"
    inreplace "src/config.rs" do |s|
      s.gsub! "persona: Persona::Ultra,", "persona: Persona::Off,"
      s.gsub! "auto_compress_md: true,", "auto_compress_md: false,"
      s.gsub! "wrap_bash: true,", "wrap_bash: false,"
    end
    inreplace "src/commands/setup.rs" do |s|
      s.gsub! 'persona = ultra\n\\', "persona = off\\n\\\nwrap_bash = false\\n\\"
      s.gsub! 'auto_compress_md = true\n\\', 'auto_compress_md = false\n\\'
    end

    system "cargo", "install", "--bin", "squeez", *std_cargo_args(root: libexec)
    prefix.install "NOTICE"

    (bin/"squeez").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail
      if [[ "${1:-}" = "update" ]]; then
        printf '%s\\n' "Error: Homebrew manages squeez upgrades. Run: brew upgrade artagon/aitools/squeez" >&2
        exit 2
      fi
      exec "#{libexec}/bin/squeez" "$@"
    SH
    chmod 0755, bin/"squeez"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `squeez update`. Use:
        brew upgrade artagon/aitools/squeez

      This build defaults to conservative settings (both unconfigured and after `squeez setup`):
        auto_compress_md = false
        persona          = off
        wrap_bash        = false

      Register the local stdio JSON-RPC MCP server with:
        #{opt_bin}/squeez mcp

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["SQUEEZ_DIR"] = (testpath/".squeez").to_s

    assert_match "squeez #{version}", shell_output("#{bin}/squeez --version")
    assert_equal "false", shell_output("#{bin}/squeez config get auto_compress_md").strip
    assert_equal "off", shell_output("#{bin}/squeez config get persona").strip
    assert_equal "false", shell_output("#{bin}/squeez config get wrap_bash").strip

    # Verify `squeez setup` writes conservative defaults to config.ini in isolated HOME.
    (testpath/".claude").mkpath
    system bin/"squeez", "setup", "--host=claude-code"
    ini = (testpath/".claude/squeez/config.ini")
    if ini.exist?
      assert_match "persona = off", ini.read
      assert_match "auto_compress_md = false", ini.read
      assert_match "wrap_bash = false", ini.read
    end
    assert_equal "false", shell_output("#{bin}/squeez config get auto_compress_md").strip
    assert_equal "off", shell_output("#{bin}/squeez config get persona").strip
    assert_equal "false", shell_output("#{bin}/squeez config get wrap_bash").strip

    shell_output("#{bin}/squeez should-wrap 'ls -la'", 1)
    assert_match "brew upgrade artagon/aitools/squeez", shell_output("#{bin}/squeez update 2>&1", 2)

    requests = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize"}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      {"jsonrpc":"2.0","id":2,"method":"tools/list"}
    JSON
    output = pipe_output("#{bin}/squeez mcp", requests, 0)
    assert_match '"name":"squeez"', output
    assert_match '"squeez_retrieve"', output
  end
end
