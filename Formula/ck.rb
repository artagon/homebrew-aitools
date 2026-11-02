class Ck < Formula
  desc "Local semantic and hybrid BM25 code search with an MCP server"
  homepage "https://github.com/BeaconBay/ck"
  license any_of: ["MIT", "Apache-2.0"]

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/BeaconBay/ck/releases/download/0.8.1/ck-0.8.1-aarch64-apple-darwin.tar.gz"
      sha256 "e9188d8c46fc8f5342738b5634b778c8041fc60f4ff7ff289179b2b6457adfd9"
    end
    on_intel do
      # Upstream builds this target without embedding features (no ONNX Runtime for Intel
      # macOS). Its --sem and --hybrid fall back to zero-vector embeddings, so only regex and
      # BM25 results are meaningful.
      url "https://github.com/BeaconBay/ck/releases/download/0.8.1/ck-0.8.1-x86_64-apple-darwin.tar.gz"
      sha256 "eedfa9e0788354c20d7bb0b4a47fb8aa199867067508ba4e181543f9eeac140a"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/BeaconBay/ck/releases/download/0.8.1/ck-0.8.1-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "65185c3ad8189cc5a468368550cabd300fd7f2a28a346bcd378697e4b524a842"
    end
    on_intel do
      url "https://github.com/BeaconBay/ck/releases/download/0.8.1/ck-0.8.1-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "042db74e0ed10cd5995024bc16ea9928de6aaef632ef6463b3b8812a8d1ba1ac"
    end
  end

  # Upstream Linux binaries need glibc 2.39 or newer (GLIBC_2.39 symbol versions).
  GLIBC_MINIMUM = "2.39".freeze

  def install
    if OS.linux? && OS::Linux::Glibc.system_version < Version.new(GLIBC_MINIMUM)
      odie <<~EOS
        ck #{version} release binaries need glibc #{GLIBC_MINIMUM} or newer; this system has
        #{OS::Linux::Glibc.system_version}. Build from source instead:
          cargo install --locked ck-search --version #{version}
      EOS
    end

    bin.install "ck"
    doc.install "README.md"
    prefix.install "LICENSE-MIT", "LICENSE-APACHE"
  end

  def caveats
    s = <<~EOS
      The first semantic or hybrid search downloads an embedding model into
        ${XDG_CACHE_HOME:-~/.cache}/ck/models
      Regex (--regex) and BM25 (--lex) searches work without it.
      `ck --serve` runs the MCP server.
    EOS
    if OS.mac? && Hardware::CPU.intel?
      s += <<~EOS

        This Intel macOS binary has no embedding support (upstream builds it without
        ONNX Runtime). --sem and --hybrid still run but rank with zero vectors, so their
        results carry no meaning. Use --lex or --regex.
      EOS
    end
    s
  end

  test do
    assert_match "ck #{version}", shell_output("#{bin}/ck --version")

    (testpath/"src/retry.py").write <<~PY
      def retry_failed_start(attempts):
          """Retry a failed server start."""
          return attempts + 1
    PY
    assert_match "retry.py:1:def retry_failed_start",
                 shell_output("#{bin}/ck --regex -n retry_failed_start #{testpath}/src")
    # BM25 needs no embedding model and no network.
    assert_match '"language":"python"',
                 shell_output("#{bin}/ck --lex --jsonl 'failed server start' #{testpath}/src")

    assert_path_exists prefix/"LICENSE-MIT"
  end
end
