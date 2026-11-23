class LangfuseCli < Formula
  desc "Command-line client for Langfuse API and versioned agent skills"
  homepage "https://github.com/langfuse/langfuse-cli"
  url "https://github.com/langfuse/langfuse-cli/archive/refs/tags/v1.4.0.tar.gz"
  sha256 "9b843ad9d84bba066acb82b64eedbb8643fcc66de7be589c137ea0daac4669b8"
  license "MIT"
  head "https://github.com/langfuse/langfuse-cli.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/langfuse-cli-1.4.0"
    rebuild 2
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "c80604ee38116001279773ba28c6055289ad55f788a3db495b159105c3ee04ff"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "b7cb63332e8dace32b69ccc98786e2272e306df2ee90e135b5dff2669b01455e"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "e3259ab39ef208695eff1023df6615a9e452967da3b847c1f522aed49f2bf0a0"
  end

  depends_on "bun" => :build
  depends_on "node"

  resource "skills" do
    url "https://github.com/langfuse/skills/archive/f0bcb13088b490c04b3f4870bace17f6d57b199c.tar.gz"
    sha256 "c89931414c66a7198e5467c9f27e71cf26711c25cd1d6a43d2a994c4ed60615f"
  end

  def install
    # Default unconfigured runs to loopback rather than Langfuse Cloud;
    # --host, --env, LANGFUSE_BASE_URL, and LANGFUSE_HOST still override it.
    inreplace "src/cli.ts",
              'const DEFAULT_HOST = "https://cloud.langfuse.com";',
              'const DEFAULT_HOST = "http://127.0.0.1:3000";'

    system "bun", "install", "--frozen-lockfile", "--ignore-scripts"
    system "bun", "run", "build"

    libexec.install "bin", "dist", "package.json"
    resource("skills").stage do
      (pkgshare/"skills").install Dir["skills/*"]
    end

    node_bin = formula_opt_bin("node")/"node"
    (bin/"langfuse").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail
      exec "#{node_bin}" "#{libexec}/bin/langfuse.mjs" "$@"
    SH
    chmod 0755, bin/"langfuse"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/langfuse-cli

      Unconfigured runs default to loopback (`http://127.0.0.1:3000`) rather than
      `https://cloud.langfuse.com`. Pass `--host`, `--env`, `LANGFUSE_BASE_URL`, or
      `LANGFUSE_HOST` to target another Langfuse deployment.

      Bundled Langfuse agent skills are installed under:
        #{opt_pkgshare}/skills

      This formula does not modify any agent configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_equal version.to_s, shell_output("#{bin}/langfuse --version").strip

    schema = JSON.parse(shell_output("#{bin}/langfuse --api-version 4 api schema --json"))
    assert_equal 4, schema["apiVersion"].to_i

    curl_out = shell_output(
      "#{bin}/langfuse --public-key pk-lf-test --secret-key sk-lf-test " \
      "--api-version 4 --curl api prompts list",
    )
    assert_match "http://127.0.0.1:3000/", curl_out
    refute_match "cloud.langfuse.com", curl_out

    assert_path_exists pkgshare/"skills/langfuse/SKILL.md"
    assert_path_exists pkgshare/"skills/migrate-to-langfuse/SKILL.md"
  end
end
