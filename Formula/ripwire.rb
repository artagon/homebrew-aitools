class Ripwire < Formula
  desc "Codebase symbol maps and call graphs for AI agents"
  homepage "https://github.com/redhat-et/ripwire"
  license "Apache-2.0"

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
  end

  def caveats
    <<~EOS
      Skills and hooks are bundled but are not activated automatically.
      Activate skills explicitly for each agent:
        bash "#{opt_pkgshare}/skills/install.sh" --claude
        bash "#{opt_pkgshare}/skills/install.sh" --codex

      Add --hook to either command to register hooks explicitly. Hooks require jq:
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
    assert_match 'symbols=2 edges=1', output
    assert_match(/<s t="fn" n="greet"[^>]*>/, output)
    assert_match(/<s t="fn" n="main"[^>]*><c n="greet"\/><\/s>/, output)

    assert_path_exists doc/"README.md"
    assert_path_exists prefix/"LICENSE"
    installer = opt_pkgshare/"skills/install.sh"
    assert_predicate installer, :executable?
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
    assert_equal testpath.to_s, ENV.fetch("HOME")
    ENV.delete("CODEX_HOME")
    ENV["AGENTS_HOME"] = (testpath/".agents").to_s
    skills = (opt_pkgshare/"skills").glob("ripwire-*/SKILL.md")
    assert_equal 17, skills.length
    %w[claude codex].each do |agent|
      system "bash", installer, "--#{agent}"
      destination = testpath/(agent == "claude" ? ".claude/skills" : ".agents/skills")
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
  end
end
