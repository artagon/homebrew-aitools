class Skillfile < Formula
  desc "Declarative package manager for AI coding agent skills"
  homepage "https://github.com/eljulians/skillfile"
  url "https://github.com/eljulians/skillfile/archive/refs/tags/v1.9.2.tar.gz"
  sha256 "c796768bf37f68346366bd9eaa7dab2f41b7e7440248b67dce9feec58b10a27a"
  license "Apache-2.0"
  head "https://github.com/eljulians/skillfile.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: "crates/cli", root: libexec)
    generate_completions_from_executable(libexec/"bin/skillfile", "completions", base_name: "skillfile")
    (bin/"skillfile").write_env_script libexec/"bin/skillfile", SKILLFILE_NO_UPDATE_NOTIFIER: "1"
  end

  def caveats
    <<~EOS
      Homebrew manages updates and disables the upstream update notifier. Use:
        brew upgrade artagon/aitools/skillfile
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match "skillfile #{version}", shell_output("#{bin}/skillfile --version")

    (testpath/"skills/example.md").write("# Example skill\n")
    (testpath/"Skillfile").write <<~EOS
      install claude-code local
      local skill example skills/example.md
    EOS
    assert_match "Skillfile OK — 1 entry, 1 install target", shell_output("#{bin}/skillfile validate")
  end
end
