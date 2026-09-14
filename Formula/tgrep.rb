class Tgrep < Formula
  desc "Trigram-indexed grep for fast regex search in large codebases"
  homepage "https://github.com/microsoft/tgrep"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/microsoft/tgrep/releases/download/v1.0.8/tgrep-v1.0.8-aarch64-apple-darwin.tar.gz"
      sha256 "b3a352060c329913750f9481c8f01de7e9b8ac33f533fd8c715b92542571659e"
    end
    on_intel do
      url "https://github.com/microsoft/tgrep/releases/download/v1.0.8/tgrep-v1.0.8-x86_64-apple-darwin.tar.gz"
      sha256 "62a1c4448aac4413363f1dedd4f73b35fb2999c46b9971fed8b8e2f2a9967aad"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/microsoft/tgrep/releases/download/v1.0.8/tgrep-v1.0.8-aarch64-unknown-linux-musl.tar.gz"
      sha256 "618e1b80a7e95b47cb91a6ececd07294c397b34ffb00e25d78600c74eb87566e"
    end
    on_intel do
      url "https://github.com/microsoft/tgrep/releases/download/v1.0.8/tgrep-v1.0.8-x86_64-unknown-linux-musl.tar.gz"
      sha256 "2e3de5b7735eb84aa150d3a48e8cff8f27c05795bfccb8b52c9bd8881f7225ce"
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
