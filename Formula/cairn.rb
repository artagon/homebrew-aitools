class Cairn < Formula
  desc "Blackboard fact-intent graph server and dispatcher for AI agents"
  homepage "https://github.com/oritera/Cairn"
  url "https://github.com/oritera/Cairn/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "425f86036d05e97d98eae4ef2d5c25cf89fdb64ddf2d1f882c3991b2016e9ec7"
  license "AGPL-3.0-only"
  head "https://github.com/oritera/Cairn.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/cairn-0.2.1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "8431f02e2bae2c12d2a80d4197c89a30bb5218a6281405a28e71235ddc8778ad"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "d20ee253f44acb72fabd25898a0490a8b46caafe2083a671e7527a3745f48081"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "f1ade0ea18870950c87b76ed1832e421a92763b6f6eddb3d1fd4c1be4745961b"
  end

  depends_on "uv" => :build

  on_linux do
    depends_on "python@3.13"
  end

  preserve_rpath

  def install
    buildpath.glob("**/.python-version").each { |file| rm(file) }

    # Strip upstream's default Aliyun PyPI mirror and lockfile so builds fetch from official PyPI.
    inreplace "cairn/pyproject.toml",
              "\n[[tool.uv.index]]\nurl = \"https://mirrors.aliyun.com/pypi/simple\"\ndefault = true",
              ""
    rm("cairn/uv.lock") if File.exist?("cairn/uv.lock")

    python_arg = if OS.mac?
      ENV["UV_PYTHON_PREFERENCE"] = "only-managed"
      ENV["UV_PYTHON_INSTALL_DIR"] = libexec/"python"
      "3.13"
    else
      ENV["UV_PYTHON_PREFERENCE"] = "only-system"
      (formula_opt_bin("python@3.13")/"python3.13").to_s
    end
    ENV["UV_TOOL_DIR"] = libexec/"tools"
    ENV["UV_TOOL_BIN_DIR"] = libexec/"bin"

    exclude_newer = "2026-11-20T00:00:00Z"
    wheels_dir = buildpath/"wheels"
    system "uv", "build", "--wheel",
           "--python", python_arg,
           "--exclude-newer", exclude_newer,
           "--no-cache",
           "--out-dir", wheels_dir,
           "cairn"

    cairn_whl = wheels_dir.glob("cairn-*.whl").fetch(0)
    system "uv", "tool", "install", cairn_whl,
           "--python", python_arg,
           "--exclude-newer", exclude_newer,
           "--no-cache"

    (libexec/"tools").glob("**/direct_url.json").each { |file| rm(file) }
    (libexec/"tools").glob("**/uv-receipt.toml").each { |file| rm(file) }

    os_tag = OS.mac? ? "darwin" : "linux"
    arch_tag = Hardware::CPU.arm? ? "arm64" : "x64"
    native_tag = "#{os_tag}-#{arch_tag}"
    (libexec/"tools").glob("**/prebuilds/*").each do |entry|
      name = entry.basename.to_s
      next if name == native_tag || name.start_with?("#{native_tag}.")

      entry.directory? ? rm_r(entry) : rm(entry)
    end
    (libexec/"tools").glob("**/pydevd_attach_to_process").each { |dir| rm_r(dir) if dir.directory? }

    # Normalize bundled dylib IDs (including hidden directories) to @rpath so
    # preserve_rpath prevents Mach-O header overflow during bottle relocation.
    if OS.mac?
      libexec.glob("**/*.dylib", File::FNM_DOTMATCH).each do |dylib|
        next if dylib.symlink? || !dylib.file?

        change_dylib_id dylib, "@rpath/#{dylib.basename}"
      end
    end

    (pkgshare/"examples").install Dir["dispatch*.yaml"]
    pkgshare.install "docs"
    (pkgshare/"skills").install "container/.agents/skills/tsec-actions"

    (bin/"cairn").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK="1"
      export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
      export PYTHONUTF8="${PYTHONUTF8:-1}"

      for arg in "$@"; do
        case "${arg}" in
          --)
            break
            ;;
          -*)
            ;;
          update | self-update | upgrade)
            printf '%s\\n' "Error: Homebrew manages cairn upgrades. Run: brew upgrade artagon/aitools/cairn" >&2
            exit 2
            ;;
          *)
            break
            ;;
        esac
      done

      exec "#{libexec}/bin/cairn" "$@"
    SH
    chmod 0755, bin/"cairn"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `cairn update`, `self-update`, or `upgrade`. Use:
        brew upgrade artagon/aitools/cairn

      `cairn serve` binds to `127.0.0.1:8000` by default with no built-in authentication
      and stores SQLite state at `~/.local/share/cairn/cairn.db` (`--db-path` overrides).
      Do not bind `--host` to a non-loopback address without an authenticated proxy or firewall.

      `cairn dispatch` requires a Docker-compatible container runtime and an explicit `--config` file.
      Example dispatcher configs, protocol specs, and the optional `tsec-actions` skill are staged under:
        #{opt_pkgshare}/examples
        #{opt_pkgshare}/docs
        #{opt_pkgshare}/skills

      This formula does not modify any agent configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s

    assert_match "Fact-graph based collaborative exploration protocol",
                 shell_output("#{bin}/cairn --help")
    assert_match "127.0.0.1", shell_output("#{bin}/cairn serve --help")
    assert_match "--startup-healthcheck-only", shell_output("#{bin}/cairn dispatch --help")

    assert_match "brew upgrade artagon/aitools/cairn", shell_output("#{bin}/cairn update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/cairn", shell_output("#{bin}/cairn self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/cairn", shell_output("#{bin}/cairn upgrade 2>&1", 2)

    srv_port = free_port
    srv_pid = spawn bin/"cairn", "serve",
                    "--host", "127.0.0.1",
                    "--port", srv_port.to_s,
                    "--db-path", (testpath/"cairn.db").to_s

    srv_ready = false
    30.times do
      if quiet_system "curl", "-fsS", "http://127.0.0.1:#{srv_port}/settings"
        srv_ready = true
        break
      end
      sleep 0.2
    end
    assert srv_ready, "cairn serve did not become ready on 127.0.0.1:#{srv_port}"

    settings = JSON.parse(shell_output("curl -fsS http://127.0.0.1:#{srv_port}/settings"))
    assert_equal 15, settings["intent_timeout"]
    assert_path_exists testpath/"cairn.db"

    docker_port = free_port
    mock_docker = testpath/"mock_docker.py"
    mock_docker.write <<~PY
      from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
      import json
      import sys

      class Handler(BaseHTTPRequestHandler):
          def log_message(self, fmt, *args):
              pass

          def _json(self, code, payload):
              body = json.dumps(payload).encode("utf-8")
              self.send_response(code)
              self.send_header("Content-Type", "application/json")
              self.send_header("Content-Length", str(len(body)))
              self.end_headers()
              self.wfile.write(body)

          def do_GET(self):
              path = self.path.split("?", 1)[0]
              if path.endswith("/version"):
                  self._json(200, {"ApiVersion": "1.45", "MinAPIVersion": "1.24"})
              elif "/exec/" in path and path.endswith("/json"):
                  self._json(200, {"ID": "exec1", "Running": False, "ExitCode": 0})
              elif "/containers/" in path and path.endswith("/json"):
                  self._json(200, {"Id": "cid1", "Name": "/mock", "State": {"Status": "running"}})
              else:
                  self._json(404, {"message": path})

          def do_POST(self):
              length = int(self.headers.get("Content-Length", "0"))
              if length:
                  self.rfile.read(length)
              path = self.path.split("?", 1)[0]
              if path.endswith("/containers/create"):
                  self._json(201, {"Id": "cid1", "Warnings": []})
              elif path.endswith("/start") and "/containers/" in path:
                  self.send_response(204)
                  self.end_headers()
              elif path.endswith("/exec") and "/containers/" in path:
                  self._json(201, {"Id": "exec1"})
              elif path.endswith("/start") and "/exec/" in path:
                  self.send_response(200)
                  self.send_header("Content-Type", "application/vnd.docker.raw-stream")
                  self.send_header("Content-Length", "0")
                  self.end_headers()
              else:
                  self._json(404, {"message": path})

          def do_DELETE(self):
              self.send_response(204)
              self.end_headers()

      ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
    PY

    docker_pid = spawn libexec/"tools/cairn/bin/python", mock_docker, docker_port.to_s
    docker_ready = false
    30.times do
      if quiet_system "curl", "-fsS", "http://127.0.0.1:#{docker_port}/version"
        docker_ready = true
        break
      end
      sleep 0.1
    end
    assert docker_ready, "mock Docker API did not become ready on 127.0.0.1:#{docker_port}"

    mock_yaml = testpath/"dispatch_mock.yaml"
    mock_yaml.write <<~YAML
      server: "http://127.0.0.1:#{srv_port}"
      runtime:
        interval: 3
        max_workers: 1
        max_running_projects: 1
        max_project_workers: 1
        healthcheck_timeout: 5
        prompt_group: "mock"
      tasks:
        bootstrap:
          timeout: 5
          conclude_timeout: 3
        reason:
          timeout: 5
          max_intents: 2
        explore:
          timeout: 5
          conclude_timeout: 3
      container:
        image: "ghcr.io/oritera/cairn-worker-container:latest"
        network_mode: "host"
        completed_action: "stop"
      workers:
        - name: "mock-observer-1"
          type: "mock"
          task_types: [reason, explore, bootstrap]
          max_running: 1
          priority: 0
          env:
            MOCK_HEALTHCHECK: '{"delay":[0,0],"outcomes":{"ok":1.0,"fail":0.0}}'
    YAML

    ENV["DOCKER_HOST"] = "tcp://127.0.0.1:#{docker_port}"
    hc_out = shell_output("#{bin}/cairn dispatch --config #{mock_yaml} --startup-healthcheck-only 2>&1")
    assert_match "Summary: total=1 healthy=1 unhealthy=0", hc_out

    assert_path_exists pkgshare/"examples/dispatch.yaml"
    assert_path_exists pkgshare/"examples/dispatch_mock.yaml"
    assert_path_exists pkgshare/"docs/specs/dispatcher-design.md"
    assert_path_exists pkgshare/"docs/specs/server-protocol.md"
    assert_path_exists pkgshare/"skills/tsec-actions/SKILL.md"
  ensure
    [docker_pid, srv_pid].compact.each do |pid|
      Process.kill("TERM", pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end
end
