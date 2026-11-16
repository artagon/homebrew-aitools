class Hindsight < Formula
  desc "Semantic agent memory CLI and local MCP server"
  homepage "https://github.com/vectorize-io/hindsight"
  url "https://github.com/vectorize-io/hindsight/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "b5534491251f89cb93cf3b4bc2062f16ed3384058c641b674e4844b446a5e8c9"
  license "MIT"
  head "https://github.com/vectorize-io/hindsight.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build
  depends_on "node"

  on_linux do
    depends_on "pkgconf" => :build
    depends_on "openssl@3"
  end

  def install
    # 1. Harden Rust CLI: default to 127.0.0.1:8888 and forbid non-loopback/cloud URLs.
    inreplace "hindsight-cli/src/config.rs" do |s|
      s.gsub! 'const DEFAULT_API_URL: &str = "http://localhost:8888";',
              'const DEFAULT_API_URL: &str = "http://127.0.0.1:8888";'
      s.gsub! '        Ok(Config {', <<~RUST.chomp
                let parsed = reqwest::Url::parse(&api_url)
                    .map_err(|e| anyhow::anyhow!("Invalid API URL {}: {}", api_url, e))?;
                match parsed.host_str() {
                    Some("127.0.0.1") | Some("localhost") | Some("[::1]") | Some("::1") => {}
                    _ => anyhow::bail!(
                        "Remote/cloud Hindsight URLs are disabled ({}); use loopback (127.0.0.1, ::1, or localhost)",
                        api_url
                    ),
                }
                Ok(Config {
      RUST
    end

    system "cargo", "install", *std_cargo_args(locked: false, path: "hindsight-cli", root: libexec/"cli")

    # 2. Harden coding-agents stdio MCP server & hooks: default to loopback self-hosted,
    #    disable autoUpdate, and reject serverMode="cloud" or non-loopback apiUrl.
    cd "hindsight-integrations/coding-agents" do
      inreplace "src/core/config.ts" do |s|
        s.gsub! <<~TS_OLD.chomp, <<~TS_NEW.chomp
          export function resolveConfig(raw: RawConfig = {}): Config {
            const serverMode = ["cloud", "self-hosted", "daemon"].includes(raw.serverMode as string)
              ? (raw.serverMode as "cloud" | "self-hosted" | "daemon")
              : "cloud";
            const apiPort = raw.apiPort || DEFAULT_DAEMON_PORT;
            const pageTrigger = resolvePageTrigger(raw);
            return {
              serverMode,
              // Daemon mode resolves the URL HERE rather than at each call site: every entry point already
              // builds its client from cfg.apiUrl, so collapsing the mode into that one field means the
              // daemon needs no plumbing through eight separate constructors.
              apiUrl:
                serverMode === "daemon"
                  ? `http://127.0.0.1:${apiPort}`
                  : (raw.apiUrl ?? "https://api.hindsight.vectorize.io"),
        TS_OLD
          function assertLoopbackUrl(candidate: string): string {
            let parsed: URL;
            try {
              parsed = new URL(candidate);
            } catch {
              throw new Error(`Invalid Hindsight apiUrl: ${candidate}`);
            }
            const host = parsed.hostname.toLowerCase();
            if (host !== "127.0.0.1" && host !== "localhost" && host !== "[::1]" && host !== "::1") {
              throw new Error(
                `Hindsight cloud/remote endpoints are disabled (${candidate}); use loopback HTTP (127.0.0.1, ::1, or localhost).`
              );
            }
            return candidate;
          }

          export function resolveConfig(raw: RawConfig = {}): Config {
            if (raw.serverMode === "cloud") {
              throw new Error("Hindsight cloud mode is disabled in this Homebrew build; use self-hosted or daemon on loopback.");
            }
            const serverMode = raw.serverMode === "daemon" ? "daemon" : "self-hosted";
            const apiPort = raw.apiPort || DEFAULT_DAEMON_PORT;
            const resolvedApiUrl = assertLoopbackUrl(
              serverMode === "daemon"
                ? `http://127.0.0.1:${apiPort}`
                : (raw.apiUrl ?? "http://127.0.0.1:8888")
            );
            const pageTrigger = resolvePageTrigger(raw);
            return {
              serverMode,
              apiUrl: resolvedApiUrl,
        TS_NEW
        s.gsub! "autoUpdate: raw.autoUpdate ?? true,", "autoUpdate: false,"
      end

      system "npm", "ci", "--ignore-scripts"
      system "npm", "run", "skill:build"
      system "npm", "run", "build"

      (libexec/"coding-agents").install "dist", "skill", "index.js", "package.json",
                                        "plugin.json", "hooks", "cordis.patch.yml"
    end

    (pkgshare/"skills").install "skills/hindsight-architect", "skills/hindsight-docs",
                                "skills/hindsight-local", "skills/hindsight-self-hosted"
    (pkgshare/"skills/hindsight-coding-agent").install Dir[libexec/"coding-agents/skill/*"]

    node_bin = Formula["node"].opt_bin/"node"

    (bin/"hindsight").write <<~SH
      #!/bin/bash
      set -euo pipefail
      exec "#{libexec}/cli/bin/hindsight" "$@"
    SH

    (bin/"hindsight-mcp").write <<~SH
      #!/bin/bash
      set -euo pipefail
      export HINDSIGHT_MCP_HARNESS="${HINDSIGHT_MCP_HARNESS:-claude-code}"
      exec "#{node_bin}" "#{libexec}/coding-agents/dist/mcp-server.js" "$@"
    SH

    (bin/"hindsight-coding-agents").write <<~SH
      #!/bin/bash
      set -euo pipefail
      prev=""
      for arg in "$@"; do
        if [ "$prev" = "--server" ] && [ "$arg" = "cloud" ]; then
          echo "Error: Hindsight cloud mode is disabled; pass '--server self-hosted' or '--server daemon'." >&2
          exit 2
        fi
        case "$arg" in
          update)
            echo "Error: Homebrew manages hindsight upgrades. Run: brew upgrade artagon/aitools/hindsight" >&2
            exit 2
            ;;
          --server)
            prev="--server"
            ;;
          --server=cloud)
            echo "Error: Hindsight cloud mode is disabled; pass '--server=self-hosted' or '--server=daemon'." >&2
            exit 2
            ;;
          *)
            prev=""
            ;;
        esac
      done
      exec "#{node_bin}" "#{libexec}/coding-agents/dist/installer.js" "$@"
    SH

    chmod 0755, [bin/"hindsight", bin/"hindsight-mcp", bin/"hindsight-coding-agents"]
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `hindsight-coding-agents update`. Use:
        brew upgrade artagon/aitools/hindsight

      This build restricts Hindsight to loopback HTTP (`127.0.0.1`, `::1`, `localhost`)
      and local stdio JSON-RPC; Hindsight Cloud endpoints are disabled.

      Register the stdio MCP server (defaults to `http://127.0.0.1:8888`):
        HINDSIGHT_MCP_HARNESS=claude-code #{opt_bin}/hindsight-mcp

      Bundled skills are installed under:
        #{opt_pkgshare}/skills

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match version.to_s, shell_output("#{bin}/hindsight --version")

    # Non-loopback / cloud URLs must fail closed in both CLI and stdio MCP server.
    ENV["HINDSIGHT_API_URL"] = "https://api.hindsight.vectorize.io"
    assert_match "loopback", shell_output("#{bin}/hindsight bank list 2>&1", 1)
    assert_match "disabled", shell_output("#{bin}/hindsight-mcp 2>&1", 1)

    # Loopback HTTP + stdio JSON-RPC initialize and tools/list must succeed.
    ENV["HINDSIGHT_API_URL"] = "http://127.0.0.1:8888"
    ENV["HINDSIGHT_MCP_HARNESS"] = "claude-code"
    system "git", "init", "--quiet"
    requests = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"brew","version":"1"}}}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      {"jsonrpc":"2.0","id":2,"method":"tools/list"}
    JSON
    output = pipe_output("#{bin}/hindsight-mcp", requests, 0)
    assert_match '"name":"hindsight"', output
    assert_match '"hindsight_reflect"', output

    assert_match "cloud mode is disabled",
                 shell_output("#{bin}/hindsight-coding-agents install claude-code --server cloud 2>&1", 2)
    assert_path_exists pkgshare/"skills/hindsight-docs/SKILL.md"
    assert_path_exists pkgshare/"skills/hindsight-coding-agent/SKILL.md"
  end
end
