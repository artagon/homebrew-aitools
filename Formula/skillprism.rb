class Skillprism < Formula
  desc "Template compiler for multi-harness AI coding agent skills"
  homepage "https://github.com/Tuvren/skillprism"
  url "https://github.com/Tuvren/skillprism/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "0cd443b4589e7e73e15319da498fd812f9a42de190a0418d0fd714454e63df63"
  license "Apache-2.0"
  head "https://github.com/Tuvren/skillprism.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/skillprism-0.6.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "19472306c82c1f4d974126d52a20cb16ae8b621600f921bfc0bda3abca6c4a27"
    sha256 cellar: :any,                 arm64_linux:  "559b63a32cf92265e144d16128dcc7856f4ca611afa1a763ffdb4f2cf470bed3"
    sha256 cellar: :any,                 x86_64_linux: "d223b348e4fdefcb0846c8368988e7c0074001865d326dc10162c2714f9f8cc7"
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
