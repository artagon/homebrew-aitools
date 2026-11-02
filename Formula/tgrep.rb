class Tgrep < Formula
  desc "Trigram-indexed grep for fast regex search in large codebases"
  homepage "https://github.com/microsoft/tgrep"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.6/tgrep-v1.2.6-aarch64-apple-darwin.tar.gz"
      sha256 "960c0d1bfe0c89b17275056d68f9e807d7fae4fd9fcc74a9320c4b962a78d584"
    end
    on_intel do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.6/tgrep-v1.2.6-x86_64-apple-darwin.tar.gz"
      sha256 "32585e597066067895557cb3f6a35b00707f232ef5cd4e05b8b2728af4daaef8"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.6/tgrep-v1.2.6-aarch64-unknown-linux-musl.tar.gz"
      sha256 "acda2a527df618ec69db59ef6b20db394be7f22b27be6cbddb3bd7f09ba96ef9"
    end
    on_intel do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.6/tgrep-v1.2.6-x86_64-unknown-linux-musl.tar.gz"
      sha256 "582737741d93c1281802188da6b7207d4a5f16b1dbe010badff12f03414d99c4"
    end
  end

  def install
    bin.install "tgrep"
    doc.install "README.md"
  end

  def caveats
    <<~EOS
      To build a trigram index for a repository:
        tgrep index .

      To run a search server in the background:
        tgrep serve . &

      To check index and server status:
        tgrep status .

      For AI coding agent guidelines, see:
        https://github.com/microsoft/tgrep/blob/main/AGENTS.md
    EOS
  end

  test do
    assert_match "tgrep #{version}", shell_output("#{bin}/tgrep --version")

    (testpath/"src/main.rs").write <<~EOS
      fn greet(name: &str) -> String {
          format!("Hello, {}!", name)
      }

      fn main() {
          println!("{}", greet("tgrep"));
      }
    EOS

    assert_path_exists doc/"README.md"

    # Test direct scan without index
    assert_match "Hello, {}!", shell_output("#{bin}/tgrep --no-index 'Hello' #{testpath}/src")

    # Test building trigram index and querying through index
    system bin/"tgrep", "index", testpath/"src"
    assert_path_exists testpath/"src/.tgrep"

    status_output = shell_output("#{bin}/tgrep status #{testpath}/src")
    assert_match "Trigrams:", status_output
    assert_match "Hidden coverage: complete", status_output

    search_output = shell_output("#{bin}/tgrep 'greet' #{testpath}/src")
    assert_match "greet(name: &str)", search_output
    assert_match "println!(\"{}\", greet(\"tgrep\"))", search_output
  end
end
