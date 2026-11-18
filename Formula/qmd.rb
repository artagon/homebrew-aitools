class Qmd < Formula
  desc "On-device hybrid BM25 and vector search CLI and MCP server"
  homepage "https://github.com/tobi/qmd"
  url "https://github.com/tobi/qmd/archive/refs/tags/v2.9.0.tar.gz"
  sha256 "e4319774537584cf566ea7e4da424716013a8fb136f76a0775fa4830e8337ea1"
  license "MIT"
  head "https://github.com/tobi/qmd.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/qmd-2.8.3"
    rebuild 2
    sha256 cellar: :any, arm64_tahoe:  "97c6cc1b6122539e35451cb79e63ae5d60f46a647218ff2a8c05f994e44ba468"
    sha256 cellar: :any, arm64_linux:  "dcb80a8f6d657f21f9b6bf5e413c404345f6b1e294c0c2b4d88fefcbe2933af0"
    sha256 cellar: :any, x86_64_linux: "78b1cdb0a4e5e0fc6fb11e46df5981881ea71de0c12b4117582285bafb41f76d"
  end

  depends_on "python@3.13" => :build
  depends_on "node"

  def install
    ENV["NODE_LLAMA_CPP_SKIP_DOWNLOAD"] = "true"

    # Remove bun/pnpm lockfiles so bin/qmd selects Homebrew's Node runtime deterministically.
    rm ["bun.lock", "pnpm-lock.yaml"]

    # Compile TypeScript dist/ first, then pack and install production + native addons into libexec.
    system "npm", "install", *std_npm_args(prefix: false)
    system "npm", "run", "build"
    system "npm", "install", *std_npm_args(ignore_scripts: false)

    # Prune prebuilt native Node addons: drop prebuilds/ completely when node-gyp
    # already compiled build/Release/ from source, and drop foreign OS/CPU prebuilds otherwise.
    native_tag = "#{OS.mac? ? "darwin" : "linux"}-#{Hardware::CPU.arm? ? "arm64" : "x64"}"
    (libexec/"lib/node_modules/@tobilu/qmd/node_modules").glob("**/prebuilds").each do |prebuilds_dir|
      next unless prebuilds_dir.directory?

      if (prebuilds_dir.parent/"build/Release").directory?
        rm_r(prebuilds_dir)
        next
      end

      prebuilds_dir.children.each do |entry|
        name = entry.basename.to_s
        next if name == native_tag || name.start_with?("#{native_tag}.")

        entry.directory? ? rm_r(entry) : rm(entry)
      end
    end

    # Retain only the host platform's CPU @node-llama-cpp addon (or Metal on Apple Silicon),
    # removing foreign-architecture and optional CUDA/Vulkan GPU addon packages.
    native_llama_pkg = if OS.mac?
      Hardware::CPU.arm? ? "mac-arm64-metal" : "mac-x64"
    else
      Hardware::CPU.arm? ? "linux-arm64" : "linux-x64"
    end
    (libexec/"lib/node_modules/@tobilu/qmd/node_modules/@node-llama-cpp").glob("*").each do |pkg_dir|
      next if !pkg_dir.directory? || pkg_dir.basename.to_s == native_llama_pkg

      rm_r(pkg_dir)
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
