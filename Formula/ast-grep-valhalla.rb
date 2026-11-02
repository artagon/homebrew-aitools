class AstGrepValhalla < Formula
  desc "Code searching, linting, rewriting with a Valhalla-aware Java grammar"
  homepage "https://ast-grep.github.io/"
  url "https://github.com/ast-grep/ast-grep/archive/refs/tags/0.51.1.tar.gz"
  sha256 "a9cb3f5cac1c0d22df189117df8d78fa3d7e9fdcd83fb5b6ab1f0b66c8835a55"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "artagon/aitools/tree-sitter-java-valhalla" => :build
  depends_on "rust" => :build

  conflicts_with "ast-grep", because: "both install `ast-grep` and `sg` binaries"

  def install
    # Build the Valhalla grammar crate in place of crates.io tree-sitter-java.
    # Both are version 0.23.5, so only that lock entry changes.
    grammar = buildpath/"tree-sitter-java-valhalla"
    cp_r Formula["artagon/aitools/tree-sitter-java-valhalla"].opt_pkgshare, grammar
    (buildpath/".cargo/config.toml").write <<~TOML
      [patch.crates-io]
      tree-sitter-java = { path = "#{grammar}" }
    TOML
    system "cargo", "update", "--package", "tree-sitter-java"
    # Cargo ignores a patch whose version no longer satisfies ast-grep's pin. Fail
    # instead of building upstream's grammar; a path dependency has no `source`.
    locked = (buildpath/"Cargo.lock").read.split("\n\n").find do |entry|
      entry.include?('name = "tree-sitter-java"')
    end
    odie "Cargo did not substitute the Valhalla tree-sitter-java crate" if locked.nil? || locked.include?("source =")

    system "cargo", "install", *std_cargo_args(path: "crates/cli")
    generate_completions_from_executable(bin/"ast-grep", "completions", shells: [:bash, :zsh, :fish, :pwsh])
  end

  test do
    (testpath/"Shapes.java").write <<~JAVA
      value record Point(int x, int y) {}

      record Plain(int z) {}

      abstract value class Shape {}
    JAVA
    pattern = "value record $NAME($$$PARAMS) { $$$BODY }"
    output = shell_output("#{bin}/ast-grep run -l java -p '#{pattern}' #{testpath}/Shapes.java")
    assert_match "value record Point", output
    refute_match "Plain", output
    # Exit status 1 means no ERROR node matched.
    assert_empty shell_output("#{bin}/ast-grep run -l java -k ERROR #{testpath}/Shapes.java", 1)

    assert_match version.to_s, shell_output("#{bin}/ast-grep --version")
  end
end
