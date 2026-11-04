class Tgrep < Formula
  desc "Trigram-indexed grep for fast regex search in large codebases"
  homepage "https://github.com/microsoft/tgrep"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.6"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "4290a043e68ef888507a70faaa84cec3b5540735f48e8c1c16821ed85540d228"
  end

  on_macos do
    on_arm do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.7/tgrep-v1.2.7-aarch64-apple-darwin.tar.gz"
      sha256 "9d98ea852d9fe61930afe036e93225d3284dbd9f555f9f2fcbefaf69af9f639b"
    end
    on_intel do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.7/tgrep-v1.2.7-x86_64-apple-darwin.tar.gz"
      sha256 "6ea185b46637ce27c736da82468089f1b3a465df4acada2a1be2a73319a9f5e0"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.7/tgrep-v1.2.7-aarch64-unknown-linux-musl.tar.gz"
      sha256 "7cc452df81a671949e692b471ee7dd2df01e2ebfb2ce38669388703cd14a0880"
    end
    on_intel do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.7/tgrep-v1.2.7-x86_64-unknown-linux-musl.tar.gz"
      sha256 "956a561524fcf9c5cc7631b99218b4d6f2e9845aae51a698aee275fdc23fd6a0"
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
