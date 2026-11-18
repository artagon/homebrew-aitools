class FffMcp < Formula
  desc "Fast, frecency-ranked file search MCP server for AI agents"
  homepage "https://github.com/dmtrKovalenko/fff"
  license "MIT"
  revision 1

  livecheck do
    url :homepage
    strategy :github_latest
  end

  on_macos do
    # Upstream release builds set MACOSX_DEPLOYMENT_TARGET=13.
    depends_on macos: :ventura

    on_arm do
      url "https://github.com/dmtrKovalenko/fff/releases/download/v0.11.0/fff-mcp-aarch64-apple-darwin"
      sha256 "cc606d9418cfa7764376dcd7b32a33e6459a6cb9a4718be366b024dca6e9fead"
    end
    on_intel do
      url "https://github.com/dmtrKovalenko/fff/releases/download/v0.11.0/fff-mcp-x86_64-apple-darwin"
      sha256 "33377a8f96442ebc8b06d3bd2863cf66a520f97a33700e0fb85a09dd7988e862"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/dmtrKovalenko/fff/releases/download/v0.11.0/fff-mcp-aarch64-unknown-linux-gnu"
      sha256 "f413fd1809f18f7ba44524010192d29562d6ba5745e33926be18b99cab6edb89"
    end
    on_intel do
      url "https://github.com/dmtrKovalenko/fff/releases/download/v0.11.0/fff-mcp-x86_64-unknown-linux-gnu"
      sha256 "1b645947cfa086f8080cd6419899e32cb2c531b122618c1141d9155e449ce647"
    end
  end

  # The release asset is a bare binary, so take upstream's license from the same tag.
  resource "license" do
    url "https://raw.githubusercontent.com/dmtrKovalenko/fff/v0.11.0/LICENSE"
    sha256 "f8264de82db188834a5711d7e348dc08c33db14f79bb587ccb42616fd694ee81"
  end

  def install
    libexec.install Dir["fff-mcp-*"].first => "fff-mcp"
    chmod 0755, libexec/"fff-mcp"
    (bin/"fff-mcp").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      has_flag=0
      is_info=0
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
          --frecency-db|--history-db|--log-file|--log-level|--max-cached-files|--idle-timeout-secs)
            skip_next=1
            ;;
          --no-update-check)
            has_flag=1
            ;;
          -h|--help|-V|--version)
            is_info=1
            ;;
          *)
            ;;
        esac
      done

      if [[ "${has_flag}" -eq 0 && "${is_info}" -eq 0 ]]; then
        exec "#{libexec}/fff-mcp" --no-update-check "$@"
      fi
      exec "#{libexec}/fff-mcp" "$@"
    SH
    chmod 0755, bin/"fff-mcp"
    resource("license").stage { prefix.install "LICENSE" }
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/fff-mcp

      Register #{opt_bin}/fff-mcp as a stdio MCP server. Startup update checks are
      disabled automatically (`--no-update-check`); pass `--frecency-db <file>` to
      rank results by frecency.
    EOS
  end

  test do
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    assert_match "fff-mcp #{version}", shell_output("#{bin}/fff-mcp --version")
    # Offline: --healthcheck returns before the update check and the MCP server start.
    (testpath/"repo").mkpath
    (testpath/"--no-update-check").mkpath
    (testpath/"state").mkpath
    output = shell_output("#{bin}/fff-mcp --healthcheck --no-update-check " \
                          "--frecency-db #{testpath}/state/frecency.db " \
                          "--history-db #{testpath}/state/history.db #{testpath}/repo")
    assert_match "All checks passed.", output
    refute_match "path not resolved", output

    delim_out = cd testpath do
      shell_output("#{bin}/fff-mcp --healthcheck " \
                   "--frecency-db #{testpath}/state/frecency2.db " \
                   "--history-db #{testpath}/state/history2.db -- --no-update-check")
    end
    assert_match "Base path: --no-update-check", delim_out
    assert_match "All checks passed.", delim_out

    assert_path_exists prefix/"LICENSE"
  end
end
