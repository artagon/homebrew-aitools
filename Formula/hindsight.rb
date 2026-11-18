class Hindsight < Formula
  desc "Semantic agent memory CLI and local MCP server"
  homepage "https://github.com/vectorize-io/hindsight"
  url "https://github.com/vectorize-io/hindsight/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "b5534491251f89cb93cf3b4bc2062f16ed3384058c641b674e4844b446a5e8c9"
  license "MIT"
  revision 1
  head "https://github.com/vectorize-io/hindsight.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build
  depends_on "node"

  on_linux do
    depends_on "pkgconf" => :build
    depends_on "openssl@4"
  end

  def install
    # 1. Harden Rust CLI: default to 127.0.0.1:8888 and forbid non-loopback/cloud URLs.
    inreplace "hindsight-cli/src/config.rs" do |s|
      s.gsub! 'const DEFAULT_API_URL: &str = "http://localhost:8888";',
              'const DEFAULT_API_URL: &str = "http://127.0.0.1:8888";'
      s.gsub! "        Ok(Config {", <<~RUST.chomp
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

    system "cargo", "generate-lockfile", "--manifest-path", "hindsight-cli/Cargo.toml"
    system "cargo", "install", *std_cargo_args(root: libexec/"cli", path: "hindsight-cli")

    # 2. Harden coding-agents stdio MCP server, hooks, and interactive installer:
    #    default to loopback self-hosted, remove Cloud choices/defaults, validate
    #    selected/migrated URLs as loopback before saving, and disable autoUpdate.
    cd "hindsight-integrations/coding-agents" do
      inreplace "src/core/config.ts" do |s|
        s.gsub! <<~TS_OLD.chomp.b, <<~TS_NEW.chomp.b
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
          export function assertLoopbackUrl(candidate: string): string {
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

      inreplace "src/installer.ts" do |s|
        s.gsub! 'import { readLegacyEndpoint } from "./core/legacy";',
                "import { assertLoopbackUrl } from \"./core/config\";\n" \
                'import { readLegacyEndpoint } from "./core/legacy";'
        s.gsub! 'const SERVER_MODES: ServerMode[] = ["cloud", "self-hosted", "daemon"];',
                'const SERVER_MODES: ServerMode[] = ["self-hosted", "daemon"];'
        s.gsub! "  { mode: \"cloud\", label: \"Hindsight Cloud\", hint: \"hosted, needs an API token\" },\n",
                ""
        s.gsub! "Choose [1-3] (default 1): ", "Choose [1-2] (default 1): "
        s.gsub! 'if (answer === "") return "cloud";', 'if (answer === "") return "self-hosted";'
        s.gsub! <<~SERVER_OLD.chomp.b, <<~SERVER_NEW.chomp.b
          function configureServer(c: InstallCtx, args: string[], installing: readonly string[]): boolean {
            const explicit = flagValue(args, "server");
            if (explicit && !SERVER_MODES.includes(explicit as ServerMode)) {
              c.log?.(`unknown --server "${explicit}" — expected one of: ${SERVER_MODES.join(", ")}`);
              return false;
            }
            // Same override as the runtime, or a user with HINDSIGHT_CONFIG set would be configured into a
            // file their sessions never read.
            const configPath = hindsightConfigPath(c);
            const existing = readJson(configPath);
            const alreadyConfigured = !!(existing.serverMode || existing.apiUrl);

            let mode = explicit as ServerMode | undefined;
            if (!mode) {
              if (alreadyConfigured) return true; // respect what's already there
              // Someone coming from the old per-agent plugin already chose where their memory lives.
              // Adopt it rather than asking again — and above all rather than defaulting to Cloud, which
              // would quietly redirect their prompts and transcripts to a different server.
              const legacy = (c.readLegacy ?? readLegacyEndpoint)(c.home, installing);
              if (legacy) {
                const carried: Record<string, unknown> = { ...existing, serverMode: legacy.serverMode };
                if (legacy.apiUrl) carried.apiUrl = legacy.apiUrl;
                if (legacy.apiToken) carried.apiToken = legacy.apiToken;
                if (legacy.apiPort) carried.apiPort = legacy.apiPort;
                writeJson(configPath, carried);
                c.log?.(
                  `server: ${legacy.serverMode}${legacy.apiUrl ? ` (${legacy.apiUrl})` : ""} — carried over ` +
                    `from the ${legacy.harness} plugin (${legacy.source})\\n` +
                    `        Only the endpoint moves; conversations do not. To bring this repo's history\\n` +
                    `        across, re-run here with --import-conversations.`
                );
                if (legacy.serverMode === "daemon") reportDaemonPrereqs(c);
                return true;
              }
              if (!c.interactive) {
                c.log?.(
                  `\\nserver: defaulting to Hindsight Cloud. Re-run with --server self-hosted|daemon to change,\\n` +
                    `        or edit ${configPath}.`
                );
                return true;
              }
              mode = promptServerMode(c);
              if (!mode) return true;
            }

            const next: Record<string, unknown> = { ...existing, serverMode: mode };
            if (mode === "cloud") {
              delete next.apiUrl; // fall back to the built-in Cloud URL rather than pinning a stale one
              // Cloud always authenticates — a config without a token only surfaces later as 401s on the
              // first session, so the token is REQUIRED here (it used to be "blank to set later").
              const token = flagValue(args, "api-token") ?? (c.interactive ? askToken(c) : undefined);
              if (!token) {
                c.log?.(
                  `❌ Hindsight Cloud needs an API token — pass --api-token <token> (or set apiToken in ${configPath}).`
                );
                return false;
              }
              next.apiToken = token;
            } else if (mode === "self-hosted") {
              const url =
                flagValue(args, "api-url") ??
                (c.interactive
                  ? readLineSync(c, "Server URL (e.g. http://localhost:8888): ").trim()
                  : undefined);
              if (!url) {
                c.log?.(
                  `❌ self-hosted mode needs a server URL — pass --api-url <url> (or set apiUrl in ${configPath}).`
                );
                return false;
              }
              next.apiUrl = url;
              const token = flagValue(args, "api-token");
              if (token) next.apiToken = token;
            } else {
              delete next.apiUrl; // daemon mode derives its URL from apiPort
              reportDaemonPrereqs(c);
            }

            writeJson(configPath, next);
            c.log?.(`server: ${mode} (${configPath})`);
            return true;
          }
        SERVER_OLD
          function configureServer(c: InstallCtx, args: string[], installing: readonly string[]): boolean {
            const explicit = flagValue(args, "server");
            if (explicit && !SERVER_MODES.includes(explicit as ServerMode)) {
              c.log?.(`unknown --server "${explicit}" — expected one of: ${SERVER_MODES.join(", ")}`);
              return false;
            }
            const configPath = hindsightConfigPath(c);
            const existing = readJson(configPath);
            const alreadyConfigured = !!(existing.serverMode || existing.apiUrl);

            let mode = explicit as ServerMode | undefined;
            if (!mode) {
              if (alreadyConfigured) return true;
              const legacy = (c.readLegacy ?? readLegacyEndpoint)(c.home, installing);
              if (legacy) {
                if (legacy.serverMode === "cloud") {
                  c.log?.("❌ Legacy Hindsight Cloud config cannot be migrated in this loopback-only build; pass --server self-hosted --api-url http://127.0.0.1:8888 or --server daemon.");
                  return false;
                }
                if (legacy.apiUrl) {
                  try {
                    assertLoopbackUrl(legacy.apiUrl);
                  } catch (err) {
                    c.log?.(`❌ ${(err as Error).message}`);
                    return false;
                  }
                }
                const carried: Record<string, unknown> = { ...existing, serverMode: legacy.serverMode };
                if (legacy.apiUrl) carried.apiUrl = legacy.apiUrl;
                if (legacy.apiToken) carried.apiToken = legacy.apiToken;
                if (legacy.apiPort) carried.apiPort = legacy.apiPort;
                writeJson(configPath, carried);
                if (legacy.serverMode === "daemon") reportDaemonPrereqs(c);
                return true;
              }
              if (!c.interactive) {
                writeJson(configPath, { ...existing, serverMode: "self-hosted", apiUrl: "http://127.0.0.1:8888" });
                c.log?.(`\\nserver: defaulting to loopback self-hosted (http://127.0.0.1:8888).`);
                return true;
              }
              mode = promptServerMode(c);
              if (!mode) return true;
            }

            const next: Record<string, unknown> = { ...existing, serverMode: mode };
            if (mode === "self-hosted") {
              const prompted = c.interactive
                ? (readLineSync(c, "Server URL (default http://127.0.0.1:8888): ").trim() || "http://127.0.0.1:8888")
                : undefined;
              const url = flagValue(args, "api-url") ?? prompted ?? "http://127.0.0.1:8888";
              try {
                assertLoopbackUrl(url);
              } catch (err) {
                c.log?.(`❌ ${(err as Error).message}`);
                return false;
              }
              next.apiUrl = url;
              const token = flagValue(args, "api-token");
              if (token) next.apiToken = token;
            } else {
              delete next.apiUrl;
              reportDaemonPrereqs(c);
            }

            writeJson(configPath, next);
            c.log?.(`server: ${mode} (${configPath})`);
            return true;
          }
        SERVER_NEW
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

    node_bin = formula_opt_bin("node")/"node"

    (bin/"hindsight").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail
      exec "#{libexec}/cli/bin/hindsight" "$@"
    SH

    (bin/"hindsight-mcp").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper; requires explicit agent harness.
      set -euo pipefail
      if [[ -z "${HINDSIGHT_MCP_HARNESS:-}" ]]; then
        printf '%s\\n' "Error: HINDSIGHT_MCP_HARNESS must be set to the invoking agent harness (e.g. claude-code, codex, antigravity-cli)." >&2
        exit 2
      fi
      exec "#{node_bin}" "#{libexec}/coding-agents/dist/mcp-server.js" "$@"
    SH

    (bin/"hindsight-coding-agents").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper; loopback self-hosted or daemon only.
      set -euo pipefail
      prev=""
      seen_subcmd=0
      for arg in "$@"; do
        if [[ "${prev}" = "--server" ]]; then
          if [[ "${arg}" = "cloud" ]]; then
            printf '%s\\n' "Error: Hindsight cloud mode is disabled; pass '--server self-hosted' or '--server daemon'." >&2
            exit 2
          fi
          prev=""
          continue
        fi
        case "${arg}" in
          --)
            break
            ;;
          --server)
            prev="--server"
            ;;
          --server=cloud)
            printf '%s\\n' "Error: Hindsight cloud mode is disabled; pass '--server=self-hosted' or '--server=daemon'." >&2
            exit 2
            ;;
          -*)
            ;;
          *)
            if [[ "${seen_subcmd}" -eq 0 ]]; then
              seen_subcmd=1
              if [[ "${arg}" = "update" ]]; then
                printf '%s\\n' "Error: Homebrew manages hindsight upgrades. Run: brew upgrade artagon/aitools/hindsight" >&2
                exit 2
              fi
            fi
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

      Register the stdio MCP server with an explicit `HINDSIGHT_MCP_HARNESS`
      (defaults to `http://127.0.0.1:8888`):
        HINDSIGHT_MCP_HARNESS=claude-code #{opt_bin}/hindsight-mcp

      Bundled skills are installed under:
        #{opt_pkgshare}/skills

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match version.to_s, shell_output("#{bin}/hindsight --version")

    # Missing HINDSIGHT_MCP_HARNESS must fail closed rather than guessing a harness.
    ENV.delete("HINDSIGHT_MCP_HARNESS")
    assert_match "HINDSIGHT_MCP_HARNESS must be set", shell_output("#{bin}/hindsight-mcp 2>&1", 2)

    # Non-loopback / cloud URLs must fail closed in CLI, MCP server, and installer.
    ENV["HINDSIGHT_MCP_HARNESS"] = "claude-code"
    ENV["HINDSIGHT_API_URL"] = "https://api.hindsight.vectorize.io"
    assert_match "loopback", shell_output("#{bin}/hindsight bank list 2>&1", 1)
    assert_match "disabled", shell_output("#{bin}/hindsight-mcp 2>&1", 1)
    assert_match "disabled",
                 shell_output(
                   "#{bin}/hindsight-coding-agents install claude-code --server self-hosted " \
                   "--api-url https://api.hindsight.vectorize.io 2>&1",
                   1,
                 )

    # Loopback HTTP + stdio JSON-RPC initialize and tools/list must succeed.
    ENV["HINDSIGHT_API_URL"] = "http://127.0.0.1:8888"
    system "git", "init", "--quiet"
    requests = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"brew","version":"1"}}}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      {"jsonrpc":"2.0","id":2,"method":"tools/list"}
    JSON
    output = pipe_output(bin/"hindsight-mcp", requests, 0)
    assert_match '"name":"hindsight"', output
    assert_match '"hindsight_reflect"', output

    assert_match "cloud mode is disabled",
                 shell_output("#{bin}/hindsight-coding-agents install claude-code --server cloud 2>&1", 2)
    assert_path_exists pkgshare/"skills/hindsight-docs/SKILL.md"
    assert_path_exists pkgshare/"skills/hindsight-coding-agent/SKILL.md"
  end
end
