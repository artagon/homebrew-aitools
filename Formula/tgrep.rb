class Tgrep < Formula
  desc "Trigram-indexed grep for fast regex search in large codebases"
  homepage "https://github.com/microsoft/tgrep"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/tgrep-1.2.8"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "bd50b937a7a762de1eaf55d3fcebc92d5dba5a55c48b579f608b74387c5245e8"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "1a66fd6674c46d95c1e16e7e0b698b34702f71830673adcdb8e3987d21a0acec"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "b2af57b052d0017cc9552f3db5854d9da4026f38cf5ef6b50f8ce605a5f15809"
  end

  on_macos do
    on_arm do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.8/tgrep-v1.2.8-aarch64-apple-darwin.tar.gz"
      sha256 "25794a307966ea0b9b685294c6c15df3000ea70ec34d50ff7380c90dc567b1e8"
    end
    on_intel do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.8/tgrep-v1.2.8-x86_64-apple-darwin.tar.gz"
      sha256 "f449cb6bc058e4780dec83cfe50961190782a55d6e6a16c9665164e6401bd572"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.8/tgrep-v1.2.8-aarch64-unknown-linux-musl.tar.gz"
      sha256 "45fa897d2bc8bad36cee1313d20c2b152ea9456e29cd093115cad6769474e2fd"
    end
    on_intel do
      url "https://github.com/microsoft/tgrep/releases/download/v1.2.8/tgrep-v1.2.8-x86_64-unknown-linux-musl.tar.gz"
      sha256 "f44032dad0c635aba3f5919f10468cf08ec8e119716f1afa751fed4c8f00ac67"
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
