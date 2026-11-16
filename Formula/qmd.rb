class Qmd < Formula
  desc "On-device hybrid BM25 and vector search CLI and MCP server"
  homepage "https://github.com/tobi/qmd"
  url "https://github.com/tobi/qmd/archive/refs/tags/v2.8.3.tar.gz"
  sha256 "851b060ef90526be6eab55384ebefabbf0573e854875256d9db9fcd53686516f"
  license "MIT"
  head "https://github.com/tobi/qmd.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "python@3.13" => :build
  depends_on "node"

  def install
    # Remove bun/pnpm lockfiles so bin/qmd always selects Homebrew's Node runtime.
    rm ["bun.lock", "pnpm-lock.yaml"]

    # Compile TypeScript dist/ first, then pack and install production + native addons into libexec.
    system "npm", "install", *std_npm_args(prefix: false)
    system "npm", "run", "build"
    system "npm", "install", *std_npm_args(ignore_scripts: false)

    # Prune prebuilt native Node addons targeting other OS/CPU architectures so the bottle stays pure.
    native_tag = "#{OS.mac? ? "darwin" : "linux"}-#{Hardware::CPU.arm? ? "arm64" : "x64"}"
    (libexec/"lib/node_modules/@tobilu/qmd/node_modules").glob("**/prebuilds/*").each do |entry|
      name = entry.basename.to_s
      next if name == native_tag || name.start_with?("#{native_tag}.")

      entry.directory? ? rm_r(entry) : rm(entry)
    end

    (pkgshare/"skills").install "skills/qmd"

    node_bin = formula_opt_bin("node")/"node"
    (bin/"qmd").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail
      export QMD_SOURCE_MODE="0"
      exec "#{node_bin}" "#{libexec}/lib/node_modules/@tobilu/qmd/bin/qmd" "$@"
    SH
    chmod 0755, bin/"qmd"
  end

  def caveats
    <<~EOS
      Register #{opt_bin}/qmd as a local stdio MCP server:
        #{opt_bin}/qmd mcp

      Or start the loopback HTTP MCP server (`localhost:8181` by default):
        #{opt_bin}/qmd mcp --http

      Bundled agent skill is installed at:
        #{opt_pkgshare}/skills/qmd

      First `qmd embed` / `qmd query` run downloads local GGUF models into ~/.cache/qmd.
      This formula does not modify any agent configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    assert_match version.to_s, shell_output("#{bin}/qmd --version")

    (testpath/"notes/architecture.md").write <<~MD
      # Provenance Architecture

      Homebrew bottles are verified with SLSA v1 attestations and Sigstore bundles.
    MD

    system bin/"qmd", "collection", "add", testpath/"notes", "--name", "notes"
    search_json = JSON.parse(shell_output("#{bin}/qmd search 'Sigstore' --json"))
    assert_operator search_json.length, :>=, 1

    requests = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"brew","version":"1"}}}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      {"jsonrpc":"2.0","id":2,"method":"tools/list"}
    JSON
    mcp_out = pipe_output("#{bin}/qmd mcp", requests, 0)
    assert_match '"query"', mcp_out

    assert_path_exists pkgshare/"skills/qmd/SKILL.md"
  end
end
