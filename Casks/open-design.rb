cask "open-design" do
  arch arm: "arm64", intel: "x64"

  version "0.27.2"
  sha256 arm:   "37324d70902bc53b7875d8743a33d85ca6c754295d7e95e32a3bfa746d692dbe",
         intel: "2d62a65e11c4880d5d3da02ea0fe88acce6d0dd05bd1e2f48c11b5c6207023db"

  url "https://github.com/nexu-io/open-design/releases/download/open-design-v#{version}/open-design-#{version}-mac-#{arch}.dmg"
  name "Open Design"
  desc "Collaborative AI design agent workspace"
  homepage "https://open-design.ai/"

  livecheck do
    url :url
    regex(/^open-design-v(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  depends_on macos: :monterey

  app "Open Design.app"
  shimscript = "#{staged_path}/open-design.wrapper.sh"
  binary shimscript, target: "open-design"

  preflight_steps do
    write_file "open-design.wrapper.sh", <<~SH, base: :staged_path
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ launcher wrapper.
      set -euo pipefail

      export OD_UPDATE_ENABLED="${OD_UPDATE_ENABLED:-0}"
      export OD_UPDATE_AUTO_CHECK="${OD_UPDATE_AUTO_CHECK:-0}"
      export OD_UPDATE_AUTO_DOWNLOAD="${OD_UPDATE_AUTO_DOWNLOAD:-0}"
      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

      app_exec="${HOMEBREW_CASK_APPDIR:-/Applications}/Open Design.app/Contents/MacOS/Open Design"
      if [[ ! -x "${app_exec}" && -x "${HOME}/Applications/Open Design.app/Contents/MacOS/Open Design" ]]; then
        app_exec="${HOME}/Applications/Open Design.app/Contents/MacOS/Open Design"
      fi

      exec "${app_exec}" "$@"
    SH
    set_permissions "open-design.wrapper.sh", "0755", base: :staged_path, recursive: false
  end

  uninstall quit: "io.open-design.desktop"

  zap trash: [
    "~/Library/Application Support/Open Design",
    "~/Library/Caches/io.open-design.desktop",
    "~/Library/Caches/io.open-design.desktop.ShipIt",
    "~/Library/HTTPStorages/io.open-design.desktop",
    "~/Library/Logs/Open Design",
    "~/Library/Preferences/io.open-design.desktop.plist",
    "~/Library/Saved Application State/io.open-design.desktop.savedState",
  ]

  caveats <<~EOS
    Homebrew manages this installation; upgrade with:
      brew upgrade --cask artagon/aitools/open-design

    Open Design uses a custom Electron/Node updater (not Sparkle or macOS
    UserDefaults) that checks `releases.open-design.ai` by default. Avoid
    in-app updates so `Open Design.app` stays under Homebrew's control, or
    launch via the bundled hardened CLI shim:
      open-design
    which exports `OD_UPDATE_ENABLED=0`, `OD_UPDATE_AUTO_CHECK=0`,
    `OD_UPDATE_AUTO_DOWNLOAD=0`, and `DO_NOT_TRACK=1` by default.

    Upstream release builds enable optional PostHog/Langfuse product analytics
    by default (choose "Don't share" on the first-run banner or disable under
    Settings -> Privacy) and keep scrubbed safety/reliability crash diagnostics
    enabled; see upstream `PRIVACY.md` for details.

    Installing or upgrading this cask does not modify `~/.claude*`, `~/.codex*`,
    `~/.gemini*`, `~/.config/*`, or shell profile files.
  EOS
end
