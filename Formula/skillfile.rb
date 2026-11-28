class Skillfile < Formula
  desc "Declarative package manager for AI coding agent skills"
  homepage "https://github.com/eljulians/skillfile"
  url "https://github.com/eljulians/skillfile/archive/refs/tags/v1.10.0.tar.gz"
  sha256 "c708c3b670ee9c1bc94ba76762cb6c14d2a91ceee597ba0923ba5d0b6efb485c"
  license "Apache-2.0"
  head "https://github.com/eljulians/skillfile.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/skillfile-1.9.3"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "3f764feadcdc119ad5fb4b04573ef06f68548d4cbe037e03a168df32f9d67a64"
    sha256 cellar: :any,                 arm64_linux:  "741a06c50b402936a6f88f7a9e8ff2f3c4a8c9f08cb86e09d68f9af8e3a4ca2a"
    sha256 cellar: :any,                 x86_64_linux: "eb7f2b6564cf7e347b9893c0f7c3e1b4921b23e95bc297e593b3f1df3a51c068"
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
