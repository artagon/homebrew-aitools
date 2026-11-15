class Skillprism < Formula
  desc "Template compiler for multi-harness AI coding agent skills"
  homepage "https://github.com/Tuvren/skillprism"
  url "https://github.com/Tuvren/skillprism/archive/refs/tags/v0.5.0.tar.gz"
  sha256 "a9f5e67b6f6ce344eca2a7cbf3c7958f5b76a129bf8bfc9b4e33dd81113c0b05"
  license "Apache-2.0"
  head "https://github.com/Tuvren/skillprism.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"skillprism", "completions")
    (man1/"skillprism.1").write Utils.safe_popen_read(bin/"skillprism", "__generate_man")
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match "skillprism #{version}", shell_output("#{bin}/skillprism --version")
    assert_path_exists man1/"skillprism.1"

    (testpath/"skillprism.yaml").write <<~YAML
      harnesses:
        - claude
      skills_dir: skills
    YAML
    (testpath/"skills/example/skill.yaml").write <<~YAML
      skillprism: '1'
      name: example
      description: Example skill
      variables:
        greeting: Hello from Homebrew
    YAML
    (testpath/"skills/example/SKILL.md.j2").write <<~EOS
      ---
      name: {{ skill_name | yaml_str }}
      description: {{ skill_description | yaml_str }}
      ---

      {{ greeting }} for {{ harness.id }}
    EOS
    system bin/"skillprism", "build"
    assert_match "Hello from Homebrew for claude", (testpath/"dist/claude/example/SKILL.md").read
  end
end
