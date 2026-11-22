cask "hammerspoon" do
  version "1.1.1"
  sha256 "11bb1c90faf5427f37c7bd4fe7eab9774ae43e1d5cb020c5b3088dac32849efa"

  url "https://github.com/Hammerspoon/hammerspoon/releases/download/#{version}/Hammerspoon-#{version}.zip"
  name "Hammerspoon"
  desc "Desktop automation application"
  homepage "https://www.hammerspoon.org/"

  livecheck do
    url "https://raw.githubusercontent.com/Hammerspoon/hammerspoon/master/appcast.xml"
    strategy :sparkle, &:short_version
  end

  depends_on macos: :ventura

  app "Hammerspoon.app"
  binary "#{appdir}/Hammerspoon.app/Contents/Frameworks/hs/hs"

  postflight_steps do
    run "/bin/bash",
        args:           [
          "-euo", "pipefail", "-c",
          <<~'SH',
            rc=0

            env_bool() {
              local raw="${1:-}"
              raw="${raw#"${raw%%[![:space:]]*}"}"
              raw="${raw%"${raw##*[![:space:]]}"}"
              if [ -z "${raw}" ]; then
                raw="${2:-}"
                raw="${raw#"${raw%%[![:space:]]*}"}"
                raw="${raw%"${raw##*[![:space:]]}"}"
              fi
              if [ -z "${raw}" ]; then
                case "${3:-0}" in
                  1) return 0 ;;
                  *) return 1 ;;
                esac
              fi
              case "${raw}" in
                1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Oo][Nn]) return 0 ;;
                0|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]|[Oo][Ff][Ff]) return 1 ;;
                *)
                  printf 'warning: ignoring invalid boolean flag value; failing closed\n' >&2
                  return 1
                  ;;
              esac
            }

            write_bool() {
              if ! /usr/bin/defaults write "$1" "$2" -bool "$3"; then
                printf 'warning: defaults write %s %s failed\n' "$1" "$2" >&2
                rc=1
              fi
            }

            if env_bool "${HOMEBREW_HAMMERSPOON_SKIP_DEFAULTS:-}" "${HOMEBREW_AITOOLS_SKIP_DEFAULTS:-}" 0; then
              exit 0
            fi

            if env_bool "${HOMEBREW_HAMMERSPOON_AUTO_UPDATES:-}" "${HOMEBREW_AITOOLS_AUTO_UPDATES:-}" 0; then
              write_bool org.hammerspoon.Hammerspoon SUEnableAutomaticChecks true
            else
              write_bool org.hammerspoon.Hammerspoon SUEnableAutomaticChecks false
              write_bool org.hammerspoon.Hammerspoon SUAutomaticallyUpdate false
              write_bool org.hammerspoon.Hammerspoon SUSendProfileInfo false
              write_bool org.hammerspoon.Hammerspoon SUHasLaunchedBefore true
            fi

            exit "${rc}"
          SH
          "_"
        ],
        writable_paths: ["Library/Preferences"],
        writable_base:  :home,
        must_succeed:   false
  end

  uninstall quit: "org.hammerspoon.Hammerspoon"

  zap trash: [
    "~/.hammerspoon",
    "~/Library/Application Support/com.crashlytics/org.hammerspoon.Hammerspoon",
    "~/Library/Caches/org.hammerspoon.Hammerspoon",
    "~/Library/Preferences/org.hammerspoon.Hammerspoon.plist",
    "~/Library/Saved Application State/org.hammerspoon.Hammerspoon.savedState",
  ]

  caveats <<~EOS
    Homebrew manages this installation; upgrade with:
      brew upgrade --cask artagon/aitools/hammerspoon

    Default postflight settings disable Sparkle automatic update checks on
    `org.hammerspoon.Hammerspoon` so the in-app updater does not replace
    `Hammerspoon.app` outside Homebrew's control.

    Override install-time settings with `HOMEBREW_*` environment flags (`brew`
    strips non-`HOMEBREW_*` variables; per-cask flags override tap-wide ones;
    accepted values are `1`/`true`/`yes`/`on` and `0`/`false`/`no`/`off`):
      HOMEBREW_HAMMERSPOON_AUTO_UPDATES=1  (or HOMEBREW_AITOOLS_AUTO_UPDATES=1)
      HOMEBREW_HAMMERSPOON_SKIP_DEFAULTS=1 (or HOMEBREW_AITOOLS_SKIP_DEFAULTS=1)

    Installing or upgrading this cask does not modify `~/.hammerspoon`,
    coding-agent configs, or shell profile files.
  EOS
end
