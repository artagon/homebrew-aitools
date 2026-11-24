class Herdr < Formula
  desc "Multiplexed terminal manager for AI coding agent sessions"
  homepage "https://github.com/herdrdev/herdr"
  license "Apache-2.0"
  revision 1

  livecheck do
    url :homepage
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5_1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "1e3c4531069684b3d2e03fa0c342a28a61b7d0948d3852423779487fa223428a"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "deb0f5e346100e83f84a3530a3a462dc099ac9e576aed46d5be3713752c7cfe6"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "a56d81547ab1388afefff7ebf9f77e172a66fa602666bb5fe227c8714a1319f1"
  end

  on_macos do
    on_arm do
      url "https://github.com/herdrdev/herdr/releases/download/v0.9.5/herdr-macos-aarch64"
      sha256 "fb77c2232a05a8035421382c894392f4174e4e38a18e48af3dd0290157c3a7e2"
    end
    on_intel do
      url "https://github.com/herdrdev/herdr/releases/download/v0.9.5/herdr-macos-x86_64"
      sha256 "5fb0a908ec7f6745e3e245738b06bfad56c46391c391ab3c0955fbead01f1369"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/herdrdev/herdr/releases/download/v0.9.5/herdr-linux-aarch64"
      sha256 "17d7536f2da50859523680ef279dffcac8e4a235f4e46fe8da6c2ec44141897c"
    end
    on_intel do
      url "https://github.com/herdrdev/herdr/releases/download/v0.9.5/herdr-linux-x86_64"
      sha256 "14d9e8bc8b4a9e0118d77c32266f76d461f09b40342eb23752960bd89f59929d"
    end
  end

  # The release asset is a bare binary, so take upstream's license from the same tag.
  resource "license" do
    url "https://raw.githubusercontent.com/herdrdev/herdr/v0.9.5/LICENSE"
    sha256 "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"
  end

  def install
    libexec.install Dir["herdr-*"].first => "herdr"
    chmod 0755, libexec/"herdr"
    resource("license").stage { prefix.install "LICENSE" }
    generate_completions_from_executable(libexec/"herdr", "completion")

    (bin/"herdr").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      skip_next=0
      cmd=""
      for arg in "$@"; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        case "${arg}" in
          --)
            break
            ;;
          -h | --help)
            break
            ;;
          --session | --machine | --remote | --remote-keybindings)
            skip_next=1
            ;;
          --*=* | -*)
            ;;
          *)
            if [[ -z "${cmd}" ]]; then
              cmd="${arg}"
              if [[ "${cmd}" = "update" ]]; then
                printf '%s\\n' "Error: Homebrew manages herdr upgrades. Run: brew upgrade artagon/aitools/herdr" >&2
                exit 2
              fi
              if [[ "${cmd}" != "channel" ]]; then
                break
              fi
            elif [[ "${cmd}" = "channel" ]]; then
              if [[ "${arg}" = "set" ]]; then
                printf '%s\\n' "Error: Homebrew manages herdr upgrades. Run: brew upgrade artagon/aitools/herdr" >&2
                exit 2
              fi
              break
            fi
            ;;
        esac
      done

      exec "#{libexec}/herdr" "$@"
    SH
    chmod 0755, bin/"herdr"
  end

  def caveats
    <<~EOS
      In-place self-updates (`herdr update` and `herdr channel set`) are disabled
      by this wrapper. Always qualify this tap when installing or upgrading:
        brew install artagon/aitools/herdr
        brew upgrade artagon/aitools/herdr
    EOS
  end

  test do
    assert_match "herdr #{version}", shell_output("#{bin}/herdr --version")
    assert_match "brew upgrade artagon/aitools/herdr", shell_output("#{bin}/herdr update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/herdr",
                 shell_output("#{bin}/herdr --session demo update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/herdr",
                 shell_output("#{bin}/herdr channel set preview 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/herdr",
                 shell_output("#{bin}/herdr channel --session demo set stable 2>&1", 2)

    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s
    ENV["XDG_STATE_HOME"] = (testpath/"state").to_s
    ENV["HERDR_CONFIG_PATH"] = (testpath/"config.toml").to_s
    ENV["HERDR_SOCKET_PATH"] = (testpath/"herdr.sock").to_s
    (testpath/"config.toml").write <<~TOML
      [update]
      version_check = false
      manifest_check = false
    TOML

    pid = spawn bin/"herdr", "server"
    status = ""
    10.times do
      status = shell_output("#{bin}/herdr status server")
      break if status.include?("status: running")

      sleep 1
    end
    assert_match "status: running", status
    assert_match "version: #{version}", status

    output = shell_output("#{bin}/herdr workspace create --label brew-test --no-focus")
    workspace = JSON.parse(output).dig("result", "workspace")
    assert_equal "brew-test", workspace["label"]

    output = shell_output("#{bin}/herdr workspace list")
    workspaces = JSON.parse(output).dig("result", "workspaces")
    assert_includes workspaces.map { |entry| entry["workspace_id"] }, workspace["workspace_id"]

    assert_path_exists prefix/"LICENSE"
  ensure
    if pid
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
