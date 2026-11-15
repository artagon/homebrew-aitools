class Herdr < Formula
  desc "Multiplexed terminal manager for AI coding agent sessions"
  homepage "https://github.com/herdrdev/herdr"
  license "Apache-2.0"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/herdr-0.9.5"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "4dfdf6be14ea11c985bda408b1d946552e6a048e661e26c844df4fffd16a28c3"
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
    bin.install Dir["herdr-*"].first => "herdr"
    chmod 0755, bin/"herdr"
    resource("license").stage { prefix.install "LICENSE" }
    generate_completions_from_executable(bin/"herdr", "completion")
  end

  def caveats
    <<~EOS
      Upgrade with `brew upgrade artagon/aitools/herdr`, not `herdr update`:
      the self-updater replaces the binary outside Homebrew's control.
    EOS
  end

  test do
    assert_match "herdr #{version}", shell_output("#{bin}/herdr --version")

    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s
    ENV["XDG_STATE_HOME"] = (testpath/"state").to_s
    ENV["HERDR_CONFIG_PATH"] = (testpath/"config.toml").to_s
    ENV["HERDR_SOCKET_PATH"] = (testpath/"herdr.sock").to_s

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
