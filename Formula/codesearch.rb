class Codesearch < Formula
  desc "Multi-repo semantic code search CLI and MCP server"
  homepage "https://github.com/flupkede/codesearch"
  url "https://github.com/flupkede/codesearch/archive/refs/tags/v1.8.11.tar.gz"
  sha256 "51859f7e8e238236d6690b9afe0c55299d6c5333e96d360d102ecb8d14ad88f5"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/codesearch-1.8.11"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "1266773200254bf33f49c8c4804c896bf1f86c74aefaee8ba40d0cde379568d2"
    sha256 cellar: :any,                 arm64_linux:  "1602427752325e28ced91c338acc2d18be8b01f6cb9080b9b0f3067b47312eb6"
    sha256 cellar: :any,                 x86_64_linux: "1c90ee2ee3e0a010f07f6b0d27d47ae2f3b4ca11281237fdc9f92764751e6713"
  end

  depends_on "protobuf" => :build
  depends_on "rust" => :build

  on_linux do
    depends_on "pkgconf" => :build
    depends_on "openssl@4"
  end

  def install
    # Override upstream .cargo/config.toml (`target-dir = "../target"`).
    ENV["CARGO_TARGET_DIR"] = (buildpath/"target").to_s
    # ort-sys statically links CoreML objects referencing ___isPlatformVersionAtLeast;
    # newer Xcode requires explicit compiler-rt linkage (upstream release.yml).
    ENV.append "RUSTFLAGS", "-Clink-arg=-fapple-link-rtlib" if OS.mac?

    system "cargo", "install", *std_cargo_args(root: libexec)

    (pkgshare/"integrations/claude-code").install "integrations/claude-code/hooks",
                                                  "integrations/claude-code/README.md"
    (pkgshare/"integrations/opencode").install "integrations/opencode/codesearch.ts",
                                               "integrations/opencode/README.md"

    (bin/"codesearch").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export CODESEARCH_SERVE_HOST="${CODESEARCH_SERVE_HOST:-127.0.0.1}"
      export CODESEARCH_EMBED_PROVIDER="${CODESEARCH_EMBED_PROVIDER:-fastembed}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-true}"

      skip_next=0
      for arg in "$@"; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        case "${arg}" in
          --)
            break
            ;;
          -l | -ql | --loglevel | --store | --model)
            skip_next=1
            ;;
          --embed-provider | --embed-base-url | --embed-dimensions | --embed-batch-size)
            skip_next=1
            ;;
          --embed-timeout-secs | --embed-concurrency | --embed-max-input-bytes)
            skip_next=1
            ;;
          --embed-query-prefix | --embed-document-prefix)
            skip_next=1
            ;;
          --*=* | -*)
            ;;
          update | self-update | upgrade)
            printf '%s\\n' "Error: Homebrew manages codesearch upgrades. Run: brew upgrade artagon/aitools/codesearch" >&2
            exit 2
            ;;
          *)
            break
            ;;
        esac
      done

      exec "#{libexec}/bin/codesearch" "$@"
    SH
    chmod 0755, bin/"codesearch"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run upstream `install.sh` or
      `codesearch update`/`self-update`/`upgrade`. Upgrade with:
        brew upgrade artagon/aitools/codesearch

      This build uses local-first defaults:
        - Local HTTP hub binds to loopback (`127.0.0.1:39725`, `CODESEARCH_SERVE_HOST=127.0.0.1`).
        - Local CPU embeddings (`CODESEARCH_EMBED_PROVIDER=fastembed`) run offline
          after the one-time model download (`codesearch setup`).

      Register as a stdio MCP server or run the local multi-repo HTTP hub:
        #{opt_bin}/codesearch mcp
        #{opt_bin}/codesearch serve

      Opt-in agent integrations are staged passively under:
        #{opt_pkgshare}/integrations/claude-code
        #{opt_pkgshare}/integrations/opencode
      Running `codesearch hooks claude install` is strictly opt-in; installing
      or upgrading this formula modifies zero agent configuration files.

      If another `codesearch` binary or script appears earlier on `$PATH`, invoke
      `#{opt_bin}/codesearch` directly or adjust `$PATH`.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["CODESEARCH_HOME"] = (testpath/".codesearch").to_s
    ENV["CODESEARCH_SERVE_PORT"] = "1"

    assert_match version.to_s, shell_output("#{bin}/codesearch --version")
    assert_match "Usage: codesearch", shell_output("#{bin}/codesearch --help")
    assert_match "127.0.0.1", shell_output("#{bin}/codesearch serve --help")
    assert_match "CODESEARCH_MCP_MODE", shell_output("#{bin}/codesearch mcp --help")

    assert_match "brew upgrade artagon/aitools/codesearch",
                 shell_output("#{bin}/codesearch update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/codesearch",
                 shell_output("#{bin}/codesearch self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/codesearch",
                 shell_output("#{bin}/codesearch upgrade 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/codesearch",
                 shell_output("#{bin}/codesearch --embed-provider fastembed update 2>&1", 2)

    # Value-bearing global options and `--` must not be misidentified as blocked subcommands.
    assert_match "No repositories registered.",
                 shell_output("#{bin}/codesearch --store update index list")
    passthrough = shell_output("#{bin}/codesearch -- update 2>&1", 2)
    refute_match "Homebrew manages codesearch upgrades", passthrough

    assert_match "No repositories registered.", shell_output("#{bin}/codesearch index list")
    assert_match "No groups defined.", shell_output("#{bin}/codesearch groups list")
    assert_match "No remote peers configured.", shell_output("#{bin}/codesearch remote list")

    (testpath/"repo/src").mkpath
    (testpath/"repo/src/lib.rs").write <<~RUST
      pub fn add(a: i32, b: i32) -> i32 {
          a + b
      }
    RUST
    dry_run = shell_output("#{bin}/codesearch index --dry-run #{testpath}/repo")
    assert_match "Found 1 indexable files", dry_run
    assert_match "Dry run complete!", dry_run

    assert_path_exists pkgshare/"integrations/claude-code/hooks/grep-guard.sh"
    assert_path_exists pkgshare/"integrations/claude-code/README.md"
    assert_path_exists pkgshare/"integrations/opencode/codesearch.ts"
    assert_path_exists pkgshare/"integrations/opencode/README.md"

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".config/opencode"
  end
end
