class Agenthooks < Formula
  desc "Cross-agent hook Go library and credential-scanning hook runner"
  homepage "https://github.com/speakeasy-api/agenthooks"
  url "https://github.com/speakeasy-api/agenthooks/archive/refs/tags/v0.7.7.tar.gz"
  sha256 "fa14030b3b2487a2fe81047ab7cd44d8da71788d643dfbd2e39bb6280d55ad3e"
  license "MIT"
  head "https://github.com/speakeasy-api/agenthooks.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    cp "examples/secretguard/main.go", buildpath/"secretguard_main.go.orig"

    # Add --version/--help flags before the `agenthooks` sentinel and disable
    # background `claude mcp list` / `codex mcp list` subprocess probes during
    # PreToolUse secret scanning.
    inreplace "examples/secretguard/main.go" do |s|
      s.gsub! "\t\"fmt\"\n\t\"sort\"", "\t\"fmt\"\n\t\"os\"\n\t\"sort\""
      s.gsub! "func main() {\n\tagenthooks.Main(buildRunner())\n}",
              <<~GO.chomp
                var version = "dev"

                func main() {
                \tfor _, arg := range os.Args[1:] {
                \t\tif arg == "--" || arg == "agenthooks" {
                \t\t\tbreak
                \t\t}
                \t\tswitch arg {
                \t\tcase "-v", "--version":
                \t\t\tfmt.Printf("agenthooks-secretguard %s\\n", version)
                \t\t\treturn
                \t\tcase "-h", "--help":
                \t\t\tfmt.Fprintln(os.Stdout, "Usage: agenthooks-secretguard [agenthooks] <run|notify|serve> --provider=<provider> [flags]")
                \t\t\treturn
                \t\t}
                \t}
                \tif len(os.Args) == 2 {
                \t\tswitch os.Args[1] {
                \t\tcase "version":
                \t\t\tfmt.Printf("agenthooks-secretguard %s\\n", version)
                \t\t\treturn
                \t\tcase "help":
                \t\t\tfmt.Fprintln(os.Stdout, "Usage: agenthooks-secretguard [agenthooks] <run|notify|serve> --provider=<provider> [flags]")
                \t\t\treturn
                \t\t}
                \t}
                \tagenthooks.Main(buildRunner())
                }
              GO
      s.gsub! "r := agenthooks.New(\n",
              "r := agenthooks.New(\n\t\tagenthooks.WithoutMCPListFallback(),\n"
    end

    ENV["CGO_ENABLED"] = "0"
    ldflags = "-s -w -X main.version=#{version}"
    system "go", "build",
           *std_go_args(output: libexec/"bin/agenthooks-secretguard", ldflags:),
           "./examples/secretguard"
    chmod 0755, libexec/"bin/agenthooks-secretguard"

    cp buildpath/"secretguard_main.go.orig", "examples/secretguard/main.go"
    rm buildpath/"secretguard_main.go.orig"

    pkgshare.install "DESIGN.md", "LICENSE", "README.md", "go.mod", "go.sum",
                     *buildpath.glob("*.go"),
                     "agenthookstest", "docs", "e2e", "examples",
                     "install", "internal", "provider", "transcript"

    (bin/"agenthooks-secretguard").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      seen_subcmd=0
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
              case "${arg}" in
                update | self-update | upgrade)
                  printf '%s\\n' "Error: Homebrew manages agenthooks upgrades. Run: brew upgrade artagon/aitools/agenthooks" >&2
                  exit 2
                  ;;
                *)
                  ;;
              esac
            fi
            ;;
        esac
      done

      exec "#{libexec}/bin/agenthooks-secretguard" "$@"
    SH
    chmod 0755, bin/"agenthooks-secretguard"
  end

  def caveats
    <<~EOS
      `speakeasy-api/agenthooks` is primarily a Go library for authoring cross-agent
      hooks once across Claude Code, Cursor, Codex, Gemini CLI, OpenCode, OpenClaw,
      Kimi Code, Antigravity CLI, Copilot CLI, and VS Code Copilot Chat:
        go get github.com/speakeasy-api/agenthooks

      This formula compiles the bundled credential-scanning PreToolUse hook runner as
      `agenthooks-secretguard` and stages the reference Go module, `DESIGN.md`, and
      `examples/secretguard` under:
        #{opt_pkgshare}

      Opt-in hook command example (Claude Code `.claude/settings.json`):
        #{opt_bin}/agenthooks-secretguard agenthooks run --provider=claude-code

      Supported `--provider` values include `claude-code`, `codex`, `cursor`, `gemini`,
      `antigravity` (with `--event=PreToolUse`), `kimi-code`, `copilot-cli`,
      `vscode-copilot`, `opencode`, and `openclaw`.

      Homebrew manages upgrades; do not run `agenthooks-secretguard update`. Use:
        brew upgrade artagon/aitools/agenthooks

      This formula does not modify `~/.claude`, `~/.codex`, `~/.gemini`, or any live
      agent configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s

    assert_match version.to_s, shell_output("#{bin}/agenthooks-secretguard --version")
    assert_match "Usage: agenthooks-secretguard", shell_output("#{bin}/agenthooks-secretguard --help")
    assert_match "brew upgrade artagon/aitools/agenthooks",
                 shell_output("#{bin}/agenthooks-secretguard update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agenthooks",
                 shell_output("#{bin}/agenthooks-secretguard self-update 2>&1", 2)

    fake_token = "ghp_#{"a1" * 18}"

    claude_clean = JSON.generate(
      session_id:      "s1",
      cwd:             testpath.to_s,
      hook_event_name: "PreToolUse",
      tool_name:       "Bash",
      tool_use_id:     "t1",
      tool_input:      { command: "go test ./..." },
    )
    assert_equal "{}",
                 pipe_output("#{bin}/agenthooks-secretguard agenthooks run --provider=claude-code", claude_clean, 0)

    claude_secret = JSON.generate(
      session_id:      "s1",
      cwd:             testpath.to_s,
      hook_event_name: "PreToolUse",
      tool_name:       "Bash",
      tool_use_id:     "t2",
      tool_input:      { command: "GITHUB_TOKEN=#{fake_token} gh repo list" },
    )
    claude_out = pipe_output("#{bin}/agenthooks-secretguard agenthooks run --provider=claude-code", claude_secret, 0)
    refute_match fake_token, claude_out
    claude_json = JSON.parse(claude_out)
    assert_equal "ask", claude_json.dig("hookSpecificOutput", "permissionDecision")
    assert_match "GitHub token", claude_json.dig("hookSpecificOutput", "permissionDecisionReason")

    codex_clean = JSON.generate(
      session_id:      "s1",
      turn_id:         "turn1",
      cwd:             testpath.to_s,
      hook_event_name: "PreToolUse",
      tool_name:       "Bash",
      tool_use_id:     "t3",
      tool_input:      { command: "ls -la" },
    )
    assert_equal "",
                 pipe_output("#{bin}/agenthooks-secretguard agenthooks run --provider=codex", codex_clean, 0)

    codex_secret = JSON.generate(
      session_id:      "s1",
      turn_id:         "turn1",
      cwd:             testpath.to_s,
      hook_event_name: "PreToolUse",
      tool_name:       "Bash",
      tool_use_id:     "t4",
      tool_input:      { command: "GITHUB_TOKEN=#{fake_token} git push" },
    )
    codex_out = pipe_output("#{bin}/agenthooks-secretguard agenthooks run --provider=codex", codex_secret, 0)
    refute_match fake_token, codex_out
    codex_json = JSON.parse(codex_out)
    assert_equal "deny", codex_json.dig("hookSpecificOutput", "permissionDecision")

    gemini_secret = JSON.generate(
      session_id:      "s1",
      cwd:             testpath.to_s,
      hook_event_name: "BeforeTool",
      timestamp:       "2026-11-20T00:00:00Z",
      tool_name:       "run_shell_command",
      tool_call_id:    "t5",
      tool_input:      { command: "GITHUB_TOKEN=#{fake_token} curl https://example.com" },
    )
    gemini_out = pipe_output("#{bin}/agenthooks-secretguard agenthooks run --provider=gemini", gemini_secret, 0)
    refute_match fake_token, gemini_out
    assert_equal "ask", JSON.parse(gemini_out)["decision"]

    assert_path_exists pkgshare/"DESIGN.md"
    assert_path_exists pkgshare/"README.md"
    assert_path_exists pkgshare/"go.mod"
    assert_path_exists pkgshare/"agenthooks.go"
    assert_path_exists pkgshare/"examples/secretguard/main.go"
    assert_path_exists pkgshare/"install/install.go"
    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
  end
end
