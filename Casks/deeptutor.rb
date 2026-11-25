cask "deeptutor" do
  arch arm: "Apple-Silicon", intel: "Intel"

  version "1.7.4"
  sha256 arm:   "afe5bb50e9b29af77dbf1a03ab1e04e4db6112dcacb61d11ef7f822b9321dd79",
         intel: "ecc86b15873e80d0d8353af06d7a191276bd74bc08f5c577c28eea060bfe66aa"

  url "https://github.com/HKUDS/DeepTutor/releases/download/v#{version}/Open-DeepTutor-MacOS-#{arch}-v#{version}.dmg"
  name "Open DeepTutor"
  desc "Agent-native intelligent learning companion desktop app"
  homepage "https://github.com/HKUDS/DeepTutor"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Open DeepTutor.app"

  uninstall quit: "org.deeptutor.open-desktop"

  zap trash: [
    "~/Library/Application Support/Open DeepTutor",
    "~/Library/Caches/org.deeptutor.open-desktop",
    "~/Library/HTTPStorages/org.deeptutor.open-desktop",
    "~/Library/Preferences/org.deeptutor.open-desktop.plist",
    "~/Library/Saved Application State/org.deeptutor.open-desktop.savedState",
  ]

  caveats <<~EOS
    Homebrew manages this installation; upgrade with:
      brew upgrade --cask artagon/aitools/deeptutor

    For the lightweight standalone CLI/SDK formula instead of the bundled desktop
    app, install:
      brew install artagon/aitools/deeptutor

    Open DeepTutor bundles its own Ed25519-signed local Python and Node runtime
    bound to `127.0.0.1` (`NEXT_TELEMETRY_DISABLED=1`), does not use Sparkle or
    macOS UserDefaults, has no automatic update discovery or app telemetry, and
    only supports manual signed bundle imports (`Core -> Install Core Update...`).
    Prefer `brew upgrade --cask artagon/aitools/deeptutor` so `Open DeepTutor.app`
    and its bundled runtime stay under Homebrew's control.

    Installing or upgrading this cask does not modify `~/.claude*`, `~/.codex*`,
    `~/.gemini*`, `~/.config/*`, or shell profile files.
  EOS
end
