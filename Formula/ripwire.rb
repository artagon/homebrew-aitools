class Ripwire < Formula
  desc "Codebase symbol maps and call graphs for AI agents"
  homepage "https://github.com/redhat-et/ripwire"
  license "Apache-2.0"
  revision 1

  on_macos do
    on_arm do
      url "https://github.com/redhat-et/ripwire/releases/download/v0.5.0/ripwire-0.5.0-macos-arm64.tar.gz"
      sha256 "f9b4d638f0f0efeac602fa6fc5037eb2871f933deccffc3b932b0c9c5dc1fe88"
    end
    on_intel do
      url "https://github.com/redhat-et/ripwire/releases/download/v0.5.0/ripwire-0.5.0-macos-x64.tar.gz"
      sha256 "0bc6b8b101cdd56c509825a8690c363cfb35a28b669076df0b32e1558a3c68cd"
    end

    depends_on macos: :sonoma
  end

  on_linux do
    on_arm do
      url "https://github.com/redhat-et/ripwire/releases/download/v0.5.0/ripwire-0.5.0-linux-arm64.tar.gz"
      sha256 "efe049b1645045e96751a51b1bc321b2d8653aa1f6ab5d7c2390eb3d49716bf0"
    end
    on_intel do
      url "https://github.com/redhat-et/ripwire/releases/download/v0.5.0/ripwire-0.5.0-linux-x64.tar.gz"
      sha256 "f06e9d7e55032e8e5c397405ed72a19d6e70767d28c8c617a925de4401779f50"
    end
  end

  def install
    bin.install "ripwire"
    pkgshare.install "skills", "hooks"
    doc.install "README.md"
    prefix.install "LICENSE"

    (bin/"ripwire-agent-install").write <<~SHELL
      #!/usr/bin/env bash
      # Multi-agent skill and hook installer for Ripwire
      # Supports: Claude Code, OpenAI Codex, Google Antigravity, Moonshot Kimi, Grok, GitHub Copilot
      set -euo pipefail

      PKGSHARE="#{opt_pkgshare}"
      INSTALLER="${RIPWIRE_INSTALLER:-$PKGSHARE/skills/install.sh}"
      if [ ! -f "$INSTALLER" ]; then
        echo "Error: Ripwire installer not found at $INSTALLER" >&2
        exit 1
      fi

      detect_claude() { command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; }
      detect_codex() { command -v codex >/dev/null 2>&1 || [ -d "${CODEX_HOME:-$HOME/.codex}" ]; }
      detect_agy() { command -v agy >/dev/null 2>&1 || [ -d "${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}" ] || [ -d "$HOME/.gemini" ]; }
      detect_kimi() { command -v kimi >/dev/null 2>&1 || [ -d "${KIMI_CODE_HOME:-$HOME/.kimi-code}" ]; }
      detect_grok() { command -v grok >/dev/null 2>&1 || [ -d "${GROK_HOME:-$HOME/.grok}" ]; }
      detect_copilot() { command -v copilot >/dev/null 2>&1 || [ -d "${COPILOT_HOME:-$HOME/.copilot}" ]; }

      usage() {
        cat <<EOF
      Usage: ripwire-agent-install [OPTIONS]

      Install Ripwire agent skills and hooks across AI agent CLIs.

      Supported Agent CLIs:
        --claude       Claude Code                  (~/.claude/skills)
        --codex        OpenAI Codex                 (~/.agents/skills)
        --agy          Google Antigravity (Agy)     (~/.gemini/antigravity-cli/skills)
        --kimi         Moonshot Kimi Code           (~/.kimi-code/skills)
        --grok         Grok CLI                     (~/.grok/skills)
        --copilot      GitHub Copilot CLI           (~/.copilot/skills)
        --shared       Cross-Agent shared root      (~/.agents/skills)

      General Options:
        --all          Install for all detected agent CLIs (default if no agent specified)
        --hook         Register advisory hooks (supported for Claude and Codex; requires jq)
        --contributor  Include contributor-only skills (e.g. ripwire-opt-remarks)
        --list         List detected agent CLIs and their status without installing
        -h, --help     Show this help message
      EOF
      }

      want_claude=0; want_codex=0; want_agy=0; want_kimi=0; want_grok=0; want_copilot=0
      want_shared=0; want_all=0; want_hook=0; want_contributor=0; action_list=0; explicit_selection=0

      while [ $# -gt 0 ]; do
        case "$1" in
          --claude)      want_claude=1; explicit_selection=1 ;;
          --codex)       want_codex=1; explicit_selection=1 ;;
          --agy)         want_agy=1; explicit_selection=1 ;;
          --kimi)        want_kimi=1; explicit_selection=1 ;;
          --grok)        want_grok=1; explicit_selection=1 ;;
          --copilot)     want_copilot=1; explicit_selection=1 ;;
          --shared)      want_shared=1; explicit_selection=1 ;;
          --all)         want_all=1 ;;
          --hook)        want_hook=1 ;;
          --contributor) want_contributor=1 ;;
          --list)        action_list=1 ;;
          -h|--help)     usage; exit 0 ;;
          *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        esac
        shift
      done

      if [ "$action_list" -eq 1 ]; then
        echo "Detected Agent CLIs:"
        printf "  %-12s %-12s %s\\n" "CLI" "Status" "Skills Target Path"
        printf "  %-12s %-12s %s\\n" "---" "------" "------------------"
        printf "  %-12s %-12s %s\\n" "claude"  "$(detect_claude  && echo 'installed' || echo 'not found')" "$HOME/.claude/skills"
        printf "  %-12s %-12s %s\\n" "codex"   "$(detect_codex   && echo 'installed' || echo 'not found')" "${AGENTS_HOME:-$HOME/.agents}/skills"
        printf "  %-12s %-12s %s\\n" "agy"     "$(detect_agy     && echo 'installed' || echo 'not found')" "${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}"
        printf "  %-12s %-12s %s\\n" "kimi"    "$(detect_kimi    && echo 'installed' || echo 'not found')" "${KIMI_CODE_HOME:-$HOME/.kimi-code}/skills"
        printf "  %-12s %-12s %s\\n" "grok"    "$(detect_grok    && echo 'installed' || echo 'not found')" "${GROK_HOME:-$HOME/.grok}/skills"
        printf "  %-12s %-12s %s\\n" "copilot" "$(detect_copilot && echo 'installed' || echo 'not found')" "${COPILOT_HOME:-$HOME/.copilot}/skills"
        exit 0
      fi

      if [ "$explicit_selection" -eq 0 ] || [ "$want_all" -eq 1 ]; then
        detect_claude  && want_claude=1
        detect_codex   && want_codex=1
        detect_agy     && want_agy=1
        detect_kimi    && want_kimi=1
        detect_grok    && want_grok=1
        detect_copilot && want_copilot=1
        if [ "$want_claude" -eq 0 ] && [ "$want_codex" -eq 0 ] && [ "$want_agy" -eq 0 ] && \
           [ "$want_kimi" -eq 0 ] && [ "$want_grok" -eq 0 ] && [ "$want_copilot" -eq 0 ]; then
          want_shared=1
        fi
      fi

      # Keep every argument array nonempty for Bash 3.2 with nounset.
      installer_args=("$INSTALLER")
      [ "$want_contributor" -eq 1 ] && installer_args+=("--contributor")
      installed_count=0

      if [ "$want_claude" -eq 1 ]; then
        echo "==> Installing Ripwire skills for Claude Code (~/.claude/skills)..."
        claude_args=("${installer_args[@]}" --claude)
        [ "$want_hook" -eq 1 ] && claude_args+=("--hook")
        bash "${claude_args[@]}"
        installed_count=$((installed_count + 1))
      fi

      if [ "$want_codex" -eq 1 ]; then
        echo "==> Installing Ripwire skills for OpenAI Codex (${AGENTS_HOME:-$HOME/.agents}/skills)..."
        codex_args=("${installer_args[@]}" --codex)
        [ "$want_hook" -eq 1 ] && codex_args+=("--hook")
        bash "${codex_args[@]}"
        installed_count=$((installed_count + 1))
      fi

      if [ "$want_agy" -eq 1 ]; then
        agy_dst="${AGY_SKILLS_DIR:-$HOME/.gemini/antigravity-cli/skills}"
        echo "==> Installing Ripwire skills for Google Antigravity ($agy_dst)..."
        mkdir -p "$agy_dst"
        bash "${installer_args[@]}" "$agy_dst"
        installed_count=$((installed_count + 1))
      fi

      if [ "$want_kimi" -eq 1 ]; then
        kimi_dst="${KIMI_CODE_HOME:-$HOME/.kimi-code}/skills"
        echo "==> Installing Ripwire skills for Kimi Code ($kimi_dst)..."
        mkdir -p "$kimi_dst"
        bash "${installer_args[@]}" "$kimi_dst"
        installed_count=$((installed_count + 1))
      fi

      if [ "$want_grok" -eq 1 ]; then
        grok_dst="${GROK_HOME:-$HOME/.grok}/skills"
        echo "==> Installing Ripwire skills for Grok ($grok_dst)..."
        mkdir -p "$grok_dst"
        bash "${installer_args[@]}" "$grok_dst"
        installed_count=$((installed_count + 1))
      fi

      if [ "$want_copilot" -eq 1 ]; then
        copilot_dst="${COPILOT_HOME:-$HOME/.copilot}/skills"
        echo "==> Installing Ripwire skills for GitHub Copilot ($copilot_dst)..."
        mkdir -p "$copilot_dst"
        bash "${installer_args[@]}" "$copilot_dst"
        installed_count=$((installed_count + 1))
      fi

      if [ "$want_shared" -eq 1 ]; then
        shared_dst="${AGENTS_HOME:-$HOME/.agents}/skills"
        echo "==> Installing Ripwire skills for Cross-Agent shared root ($shared_dst)..."
        mkdir -p "$shared_dst"
        bash "${installer_args[@]}" "$shared_dst"
        installed_count=$((installed_count + 1))
      fi

      if [ "$want_hook" -eq 1 ] && { [ "$want_agy" -eq 1 ] || [ "$want_kimi" -eq 1 ] || [ "$want_grok" -eq 1 ] || [ "$want_copilot" -eq 1 ]; }; then
        echo ""
        echo "Note: Ripwire advisory hooks are natively supported for Claude Code and Codex."
        echo "For Antigravity, Kimi, Grok, and Copilot, Ripwire operates via skills and its MCP server ('ripwire --mcp')."
      fi

      echo "Installation complete for $installed_count agent target(s)."
    SHELL
  end

  def caveats
    <<~EOS
      Skills and hooks are bundled but are not activated automatically.
      Install skills for detected AI agent CLIs (Claude, Codex, Agy, Kimi, Grok, Copilot):
        ripwire-agent-install

      Or install for specific agents and optionally add advisory hooks:
        ripwire-agent-install --claude --hook
        ripwire-agent-install --codex --hook
        ripwire-agent-install --agy --kimi --grok --copilot

      Hooks require jq:
        brew install jq

      Rerun activation after upgrades to refresh added or removed skills.
      Installation and upgrades do not modify agent configuration or shell profiles.
    EOS
  end

  test do
    assert_match "ripwire #{version} ", shell_output("#{bin}/ripwire --version")

    (testpath/"fixture/main.ts").write <<~EOS
      export function greet(name: string): string {
        return `Hello, ${name}!`;
      }

      export function main(): string {
        return greet("Homebrew");
      }
    EOS
    output = shell_output("#{bin}/ripwire #{testpath}/fixture --no-cache")
    assert_match "symbols=2 edges=1", output
    assert_match(/<s t="fn" n="greet"[^>]*>/, output)
    assert_match %r{<s t="fn" n="main"[^>]*><c n="greet"/></s>}, output

    assert_path_exists doc/"README.md"
    assert_path_exists prefix/"LICENSE"
    installer = opt_pkgshare/"skills/install.sh"
    assert_predicate installer, :executable?
    assert_predicate bin/"ripwire-agent-install", :executable?
    assert_match "Usage:", shell_output("#{bin}/ripwire-agent-install --help")
    assert_match "claude", shell_output("#{bin}/ripwire-agent-install --list")
    %w[
      ripwire-nudge.sh
      ripwire-codex-nudge.sh
      ripwire-claude-route.sh
      ripwire-claude-toolroute.sh
      ripwire-codex-route.sh
    ].each do |hook|
      assert_predicate opt_pkgshare/"hooks"/hook, :executable?
    end

    # Homebrew supplies an isolated HOME; clear agent overrides before activation.
    assert_equal testpath.to_s, Dir.home
    ENV.delete("CODEX_HOME")
    ENV["AGENTS_HOME"] = (testpath/".agents").to_s
    skills = (opt_pkgshare/"skills").glob("ripwire-*/SKILL.md")
    assert_equal 17, skills.length
    installer_shell = OS.mac? ? "/bin/bash" : "bash"
    %w[claude codex].each do |agent|
      system installer_shell, bin/"ripwire-agent-install", "--#{agent}"
      destination = testpath/((agent == "claude") ? ".claude/skills" : ".agents/skills")
      assert_path_exists destination/".ripwire-manifest-v1"
      skills.each do |skill|
        link = destination/skill.parent.basename
        if skill.read.match?(/^audience: contributor$/)
          refute_path_exists link
        else
          assert_predicate link, :symlink?
          assert_equal "#{skill.parent}/", link.readlink.to_s
          assert_equal skill.read, (link/"SKILL.md").read
        end
      end
    end
    refute_path_exists testpath/".claude/settings.json"
    refute_path_exists testpath/".codex/hooks.json"
    refute_path_exists testpath/".codex/config.toml"

    system installer_shell, bin/"ripwire-agent-install", "--agy", "--kimi", "--grok", "--copilot"
    assert_path_exists testpath/".gemini/antigravity-cli/skills/.ripwire-manifest-v1"
    assert_path_exists testpath/".kimi-code/skills/.ripwire-manifest-v1"
    assert_path_exists testpath/".grok/skills/.ripwire-manifest-v1"
    assert_path_exists testpath/".copilot/skills/.ripwire-manifest-v1"
  end
end
