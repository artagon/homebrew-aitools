class Magpie < Formula
  desc "Subscription-first local gateway and router for AI coding agents"
  homepage "https://usemagpie.ai"
  url "https://github.com/yetone/magpie/archive/refs/tags/v0.1.4743.tar.gz"
  sha256 "6344eed4d1d3a18d21c858e4f7c3da9bf5535b77a5aad37de655c63fa36dca1f"
  license "MIT"
  head "https://github.com/yetone/magpie.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/magpie-0.1.4704"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "fcaa3a9ecce5f49ddf661bea26612097080c3971cc60520108a19cc4bcb14e7a"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "a19bbbd898ea231cb35684f39b4e9819a098e27cfc64b5a46ac0261d6c77cd1d"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "568a1ad5c78425414740790eaa5be9b3a4c39e87bce5d5a961a000b9bbe2c259"
  end

  depends_on "go" => :build

  def install
    # 1. Block in-place self-updates (`magpie update`) so Homebrew retains ownership.
    inreplace "internal/cli/main.go",
              "\tupdate.GUI = hasGUI\n\terr = run(os.Args[1:])",
              <<~GO.chomp
                \tupdate.GUI = hasGUI
                \tif len(os.Args) > 1 && os.Args[1] == "update" {
                \t\tfmt.Fprintln(os.Stderr, "Error: Homebrew manages magpie upgrades. Run: brew upgrade artagon/aitools/magpie")
                \t\tos.Exit(2)
                \t}
                \terr = run(os.Args[1:])
              GO

    # 2. Disable telemetry, background update checks/downloads, unsolicited local PII
    #    model downloads, and Claude extra-usage billing out of the box.
    inreplace "internal/settings/settings.go" do |s|
      s.gsub! "\t\tif os.IsNotExist(err) {\n" \
              "\t\t\t// a new install: With window is its default\n" \
              "\t\t\ts.DockSettled = true",
              "\t\tif os.IsNotExist(err) {\n\t\t\ts.DockSettled = true\n" \
              "\t\t\ts.RedactModelOff = true\n\t\t\ts.ClaudeNoExtraUsage = true"
      s.gsub! "func Defaults() Settings {\n\treturn Settings{DockSettled: true}.normal()\n}",
              "func Defaults() Settings {\n" \
              "\treturn Settings{DockSettled: true, RedactModelOff: true, ClaudeNoExtraUsage: true}.normal()\n}"
      s.gsub! "func (s Settings) normal() Settings {\n\ts.Name = CleanName(s.Name)",
              <<~GO.chomp
                func (s Settings) normal() Settings {
                \ts.NoStats = true
                \ts.NoUsageStats = true
                \ts.NoAutoUpdate = true
                \ts.NoAutoDownload = true
                \ts.NoUpdatePill = true
                \ts.Name = CleanName(s.Name)
              GO
    end

    # 3. Hold Claude and ChatGPT/Codex subscriptions at 100% of their plan windows
    #    instead of billing paid extra-usage or overage credits unless opted in.
    inreplace "internal/provider/claude_extra.go",
              "import \"github.com/yetone/magpie/internal/settings\"\n\n" \
              "// ClaudeExtraUsage says whether magpie sends a Claude account requests\n" \
              "// once its plan is used up, for Anthropic to bill as extra usage: true\n" \
              "// unless the user turned it off.\n" \
              "func ClaudeExtraUsage() bool { return !settings.Shared().ClaudeNoExtraUsage }",
              <<~GO.chomp
                import (
                \t"os"

                \t"github.com/yetone/magpie/internal/settings"
                )

                func ClaudeExtraUsage() bool {
                \treturn os.Getenv("MAGPIE_ALLOW_CREDITS") == "1" && !settings.Shared().ClaudeNoExtraUsage
                }
              GO

    inreplace "internal/provider/codex_credits.go" do |s|
      s.gsub! "\t\"fmt\"\n\t\"slices\"", "\t\"fmt\"\n\t\"os\"\n\t\"slices\""
      s.gsub! "func CodexCredits(user string) bool {\n" \
              "\treturn !slices.Contains(settings.Load().CodexNoCredits, accountKey(user))\n}",
              <<~GO.chomp
                func CodexCredits(user string) bool {
                \treturn os.Getenv("MAGPIE_ALLOW_CREDITS") == "1" && !slices.Contains(settings.Load().CodexNoCredits, accountKey(user))
                }
              GO
    end

    # 4. Enforce CLI-subscription-only mode (no paid API keys) unless MAGPIE_ALLOW_API_KEYS=1.
    inreplace "internal/provider/provider.go" do |s|
      s.gsub! "func (p Provider) Ready() bool {\n\tif p.IsVertex() {",
              <<~GO.chomp
                func (p Provider) Ready() bool {
                \tif os.Getenv("MAGPIE_ALLOW_API_KEYS") != "1" && p.Account == nil &&
                \t\t(p.Key != "" || len(p.Keys) > 0 || p.AccessKeyID != "" || p.SecretAccessKey != "" || p.IsVertex()) {
                \t\treturn false
                \t}
                \tif p.IsVertex() {
              GO
      s.gsub! "\tif p.Name == \"\" {\n\t\tp.Name = p.ID\n\t}\n\tif _, ok := find(Accounts(), p.ID);",
              <<~GO.chomp
                \tif p.Name == "" {
                \t\tp.Name = p.ID
                \t}
                \tif os.Getenv("MAGPIE_ALLOW_API_KEYS") != "1" {
                \t\t_, isSignedInAccount := find(Accounts(), p.ID)
                \t\tif !isSignedInAccount &&
                \t\t\t(p.Key != "" || len(p.Keys) > 0 || p.AccessKeyID != "" || p.SecretAccessKey != "" || p.IsVertex() || !keyOptional(p)) {
                \t\t\treturn errors.New("API-key providers are disabled in subscription-only mode; sign in via 'magpie accounts add claude|codex|copilot|gemini' (or set MAGPIE_ALLOW_API_KEYS=1)")
                \t\t}
                \t}
                \tif _, ok := find(Accounts(), p.ID);
              GO
    end

    system "go", "run", "./build/assetpack", "internal/gui/assets", "internal/gui/assets.zip"

    ldflags = "-s -w -X main.version=v#{version}"
    if OS.mac?
      ENV["CGO_CFLAGS"] = "-mmacosx-version-min=12.0"
      ENV["CGO_LDFLAGS"] = "-mmacosx-version-min=12.0"
      overlay_arg = Utils.safe_popen_read("sh", "build/darwin/footprint-overlay.sh", ".overlay").strip
      system "go", "build", overlay_arg, "-tags", "production packedassets",
             *std_go_args(ldflags:), "."
    else
      ENV["CGO_ENABLED"] = "0"
      system "go", "build", "-tags", "nogui packedassets",
             *std_go_args(ldflags:), "."
    end

    prefix.install "THIRD_PARTY_NOTICES"
    doc.install "README.md"

    (pkgshare/"examples/subscription-only/setup-groups.sh").write <<~SH
      #!/usr/bin/env bash
      # Configure CLI-subscription-only routing groups in magpie (no API keys).
      # Target contract: macOS /bin/bash 3.2+.
      set -euo pipefail

      magpie_bin="${MAGPIE_BIN:-#{opt_bin}/magpie}"

      "${magpie_bin}" settings set lan off
      "${magpie_bin}" settings set groupSink on
      "${magpie_bin}" settings set groupPatience 90
      "${magpie_bin}" settings set redact on
      "${magpie_bin}" settings set redactPersonal off
      "${magpie_bin}" settings set redactWordsWhole on

      "${magpie_bin}" group add sub-coder \
        models=claude/claude-sonnet-4-5,codex/gpt-5.2-codex,copilot/claude-sonnet-4.5 \
        routing=smart stays=session

      "${magpie_bin}" group add sub-architect \
        models=claude/claude-opus-4-5,codex/gpt-5.2-codex \
        routing=smart stays=session

      "${magpie_bin}" group add sub-subagent \
        models=codex/gpt-5.2-codex,copilot/claude-sonnet-4.5,gemini/gemini-2.5-pro \
        routing=smart stays=session

      "${magpie_bin}" group add sub-smol \
        models=copilot/gpt-5-mini,gemini/gemini-2.5-flash,claude/claude-haiku-4-5 \
        routing=smart stays=turn

      "${magpie_bin}" group rule add sub-coder use=group/sub-smol compact
      "${magpie_bin}" group rule add sub-coder use=group/sub-smol when="effort is off" when="not subagent"
    SH
    chmod 0755, pkgshare/"examples/subscription-only/setup-groups.sh"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `magpie update`. Use:
        brew upgrade artagon/aitools/magpie

      This build enforces CLI-subscription-only mode on loopback (`127.0.0.1:3425`)
      by default:
        - Telemetry (`noStats`, `noUsageStats`), auto-updates (`noAutoUpdate`),
          and background PII model downloads (`redactModelOff`) are disabled.
        - API-key providers and paid subscription extra-usage/overage credits
          are disabled unless `MAGPIE_ALLOW_API_KEYS=1` or `MAGPIE_ALLOW_CREDITS=1`
          is explicitly set.

      Sign in with CLI subscriptions only (no API keys):
        magpie accounts add claude
        magpie accounts add codex
        magpie accounts add copilot
        magpie accounts add gemini

      Run the menu-bar gateway (`magpie tray`), terminal UI (`magpie tui`),
      browser UI (`magpie web --no-open`), or headless server (`magpie serve`).
      A subscription-only routing group bootstrap script is staged at:
        #{opt_pkgshare}/examples/subscription-only/setup-groups.sh

      This formula does not modify any live agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    assert_match "magpie v#{version}", shell_output("#{bin}/magpie --version")
    assert_match "brew upgrade artagon/aitools/magpie",
                 shell_output("#{bin}/magpie update 2>&1", 2)

    settings_json = JSON.parse(shell_output("#{bin}/magpie settings --json"))
    assert settings_json.is_a?(Hash) || settings_json.is_a?(Array)

    # API-key providers must be rejected in subscription-only mode.
    output = shell_output("#{bin}/magpie provider add openai sk-test1234567890 2>&1", 1)
    assert_match "subscription-only mode", output

    port = free_port
    ENV["MAGPIE_ADDR"] = "127.0.0.1:#{port}"
    pid = spawn bin/"magpie", "serve"
    ready = false
    20.times do
      if quiet_system bin/"magpie", "healthcheck"
        ready = true
        break
      end
      sleep 0.5
    end
    assert ready, "magpie gateway did not become healthy on 127.0.0.1:#{port}"

    assert_path_exists prefix/"THIRD_PARTY_NOTICES"
    assert_path_exists pkgshare/"examples/subscription-only/setup-groups.sh"
  ensure
    if pid
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
