cask "agency-agents" do
  arch arm: "aarch64", intel: "x64"

  version "0.3.2"
  sha256 arm:   "c1a291e1db7bb7599edbe217ae62a28b855e14d8dfa51452659261ed6e2af06b",
         intel: "8db1ec85d330bd7f6c3e6c8ab7df7abdcb262ae97fb6e602b61f74d25ecce497"

  url "https://github.com/msitarzewski/agency-agents-app/releases/download/v#{version}/Agency_Agents_#{version}_#{arch}.dmg"
  name "Agency Agents"
  desc "Native desktop manager for installing and tracking AI agent personas"
  homepage "https://agencyagents.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Agency Agents.app"

  uninstall quit: "com.zerologic.agency-agents-app"

  zap trash: [
    "~/Library/Application Support/com.zerologic.agency-agents-app",
    "~/Library/Caches/com.zerologic.agency-agents-app",
    "~/Library/HTTPStorages/com.zerologic.agency-agents-app",
    "~/Library/Preferences/com.zerologic.agency-agents-app.plist",
    "~/Library/Saved Application State/com.zerologic.agency-agents-app.savedState",
    "~/Library/WebKit/com.zerologic.agency-agents-app",
  ]

  caveats <<~EOS
    Homebrew manages this installation; upgrade with:
      brew upgrade --cask artagon/aitools/agency-agents

    Agency Agents uses Tauri's in-app updater (not Sparkle or macOS
    UserDefaults) with automatic update checks disabled by default
    (`updateAutoCheck: false`) and includes no telemetry or crash reporting.
    Leave automatic update checks off in Settings so the in-app updater does
    not replace `Agency Agents.app` outside Homebrew's control.

    Installing or upgrading this cask does not modify `~/.claude*`, `~/.codex*`,
    `~/.gemini*`, `~/.config/*`, or shell profile files.
  EOS
end
