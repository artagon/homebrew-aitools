class Hashline < Formula
  desc "Hash-anchored line editing for AI coding agents"
  homepage "https://github.com/quangdang46/hashline"
  url "https://github.com/quangdang46/hashline/archive/refs/tags/v0.9.25.tar.gz"
  sha256 "401cae569179cf68f51c6ab3ca063aeb3924cef1fda5ab4bb3590591bea1d3d2"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/quangdang46/hashline.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/hashline-0.9.24_1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "cf130d135a6f40247826d1d334105b8cb346ef085d355ac29230f383ef004ab6"
    sha256 cellar: :any,                 arm64_linux:  "677ff498f8eec8f2d87fd16775cfead5000dbeccd035a112eb0124fcb78e13ea"
    sha256 cellar: :any,                 x86_64_linux: "6e46c81c1c757c38a69403b576c6e48dcac86b741b118128a4f0002cff29bcd4"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: "crates/core", root: libexec)
    # Homebrew owns upgrades, so the wrapper turns off the upstream update notice.
    (bin/"hashline").write_env_script libexec/"bin/hashline", HASHLINE_NO_UPDATE_CHECK: "1"

    (pkgshare/"skills/hashline/SKILL.md").write <<~EOS
      ---
      name: hashline
      description: Edit existing files with hash-anchored patches through the hashline tool. Use when you change a file that already exists.
      ---

      # Editing with hashline

      1. Read the file with hashline before you edit it: `hashline read <file>`, or the MCP tool `read`.
      2. Use only the anchors from your most recent hashline read of that file.
      3. Put all changes to one file in one patch: `hashline patch <file> '<patch>'`, or the MCP tool `patch`.
      4. If the patch fails because the content changed, read the file again and try one more time.
      5. After two failures on the same file, use your built-in edit tool and say so in your report.
      6. Create a new file with your built-in write tool.
      7. After any edit that did not go through hashline, or after a formatter run, read the file again before the next patch.
      8. Do not remove or rename a file through hashline unless the user asked for that change.

      Run `hashline guide` for the full patch language. It always matches the installed version.
    EOS
  end

  def caveats
    <<~EOS
      Homebrew manages this copy. Do not run `hashline update`. Use:
        brew upgrade artagon/aitools/hashline

      To register the MCP server, use the path that stays valid after an upgrade:
        #{opt_bin}/hashline mcp
      Example for Claude Code:
        claude mcp add hashline -- #{opt_bin}/hashline mcp

      An agent skill file is in:
        #{opt_pkgshare}/skills/hashline
      Copy or link that directory into the skill directory of your agent.

      This formula does not change any agent configuration file.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/hashline --version")
    assert_path_exists pkgshare/"skills/hashline/SKILL.md"
    (testpath/"sample.txt").write("alpha\nbeta\n")
    assert_match "alpha", shell_output("#{bin}/hashline read sample.txt")
    system bin/"hashline", "patch", "sample.txt", "DEL 2"
    refute_match "beta", (testpath/"sample.txt").read
  end
end
