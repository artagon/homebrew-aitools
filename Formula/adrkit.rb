class Adrkit < Formula
  desc "Architecture governance CLI and MCP server for AI coding agents"
  homepage "https://github.com/mbeacom/adrkit"
  url "https://github.com/mbeacom/adrkit/archive/refs/tags/v0.20.0.tar.gz"
  sha256 "58e22e45f1dd27629711ad11968195c5acd597bb8f889cab3a188b19d892ec77"
  license "Apache-2.0"
  revision 1
  head "https://github.com/mbeacom/adrkit.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "bun" => :build
  depends_on "node"

  conflicts_with "adr-tools", because: "both install `adr` binaries"

  def install
    # Build the same Node bundles as upstream's Containerfile.
    system "bun", "install", "--frozen-lockfile", "--production", "--ignore-scripts"
    system "bun", "build", "packages/cli/src/index.ts", "--target=node", "--conditions", "bun",
           "--outfile=#{libexec}/adr.js"
    system "bun", "build", "packages/mcp/src/bin.ts", "--target=node", "--conditions", "bun",
           "--outfile=#{libexec}/adrkit-mcp.js"
    # The bundles are ES modules; say so instead of relying on Node's syntax detection.
    (libexec/"package.json").write <<~JSON
      { "type": "module" }
    JSON

    # Run Homebrew's node explicitly, whatever `node` is first on PATH.
    { "adr" => "adr.js", "adrkit" => "adr.js", "adrkit-mcp" => "adrkit-mcp.js" }.each do |name, script|
      (bin/name).write <<~SH
        #!/bin/bash
        exec "#{formula_opt_bin("node")}/node" "#{libexec}/#{script}" "$@"
      SH
      chmod 0755, bin/name
    end

    pkgshare.install "packages/adapters/agent-plugin/skills"
    generate_completions_from_executable(bin/"adr", "completion")
  end

  def caveats
    <<~EOS
      Register #{opt_bin}/adrkit-mcp as a stdio MCP server. It must run inside a Git
      worktree with an ADR directory (default: docs/adr); pass --cwd and --dir to
      point it elsewhere.

      Agent skills are installed in:
        #{opt_pkgshare}/skills

      This formula modifies no agent configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["NO_COLOR"] = "1"

    assert_equal version.to_s, shell_output("#{bin}/adr --version").strip
    assert_equal version.to_s, shell_output("#{bin}/adrkit --version").strip

    record = JSON.parse(shell_output("#{bin}/adr new 'Adopt Homebrew' --json"))
    assert_equal "docs/adr/0001-adopt-homebrew.md", record["path"]
    lint = JSON.parse(shell_output("#{bin}/adr lint --json"))
    assert_equal 1, lint["checked"]
    assert_empty lint["findings"]
    assert JSON.parse(shell_output("#{bin}/adr check --json #{record["path"]}"))["ok"]

    # The MCP server needs a Git worktree; it exits when stdin closes.
    system "git", "init", "--quiet"
    requests = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"brew","version":"1"}}}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      {"jsonrpc":"2.0","id":2,"method":"tools/list"}
    JSON
    output = pipe_output("#{bin}/adrkit-mcp --cwd #{testpath}", requests, 0)
    assert_match '"name":"@adrkit/mcp"', output
    assert_match '"name":"get_decision"', output

    assert_path_exists pkgshare/"skills/decision-memory/SKILL.md"
  end
end
