cask "ghostty" do
  version "1.4.0"
  sha256 "3a02075dbd24318d778426af41dee5507d53ecc4578ede96912ec9ce6d18d3e8"

  url "https://release.files.ghostty.org/#{version}/Ghostty.dmg"
  name "Ghostty"
  desc "Terminal emulator that uses platform-native UI and GPU acceleration"
  homepage "https://ghostty.org/"

  livecheck do
    url "https://release.files.ghostty.org/appcast.xml"
    strategy :sparkle, &:short_version
  end

  conflicts_with cask: "ghostty@tip"
  depends_on macos: :ventura

  # Ghostty's shell integration adds Contents/MacOS to PATH automatically;
  # symlinking the `ghostty` binary outside Ghostty.app is intentionally omitted
  # upstream (ghostty-org/ghostty#8679, Homebrew/homebrew-cask#228639).
  app "Ghostty.app"
  manpage "#{appdir}/Ghostty.app/Contents/Resources/man/man1/ghostty.1"
  manpage "#{appdir}/Ghostty.app/Contents/Resources/man/man5/ghostty.5"
  bash_completion "#{appdir}/Ghostty.app/Contents/Resources/bash-completion/completions/ghostty.bash"
  zsh_completion "#{appdir}/Ghostty.app/Contents/Resources/zsh/site-functions/_ghostty"
  fish_completion "#{appdir}/Ghostty.app/Contents/Resources/fish/vendor_completions.d/ghostty.fish"

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

            if env_bool "${HOMEBREW_GHOSTTY_SKIP_DEFAULTS:-}" "${HOMEBREW_AITOOLS_SKIP_DEFAULTS:-}" 0; then
              exit 0
            fi

            if env_bool "${HOMEBREW_GHOSTTY_AUTO_UPDATES:-}" "${HOMEBREW_AITOOLS_AUTO_UPDATES:-}" 0; then
              write_bool com.mitchellh.ghostty SUEnableAutomaticChecks true
            else
              write_bool com.mitchellh.ghostty SUEnableAutomaticChecks false
              write_bool com.mitchellh.ghostty SUAutomaticallyUpdate false
              write_bool com.mitchellh.ghostty SUSendProfileInfo false
              write_bool com.mitchellh.ghostty SUHasLaunchedBefore true
            fi

            exit "${rc}"
          SH
          "_"
        ],
        writable_paths: ["Library/Preferences"],
        writable_base:  :home,
        must_succeed:   false
  end

  uninstall quit: "com.mitchellh.ghostty"

  zap trash: [
    "~/.cache/ghostty",
    "~/.config/ghostty",
    "~/Library/Application Support/com.mitchellh.ghostty",
    "~/Library/Caches/com.mitchellh.ghostty",
    "~/Library/HTTPStorages/com.mitchellh.ghostty",
    "~/Library/Preferences/com.mitchellh.ghostty.plist",
    "~/Library/Saved Application State/com.mitchellh.ghostty.savedState",
    "~/Library/WebKit/com.mitchellh.ghostty",
  ]

  caveats <<~EOS
    Homebrew manages this installation; upgrade with:
      brew upgrade --cask artagon/aitools/ghostty

    Default postflight settings disable Sparkle automatic update checks on
    `com.mitchellh.ghostty` so the in-app updater does not replace `Ghostty.app`
    outside Homebrew's control. You can also set `auto-update = off` in your
    Ghostty config.

    Override install-time settings with `HOMEBREW_*` environment flags (`brew`
    strips non-`HOMEBREW_*` variables; per-cask flags override tap-wide ones;
    accepted values are `1`/`true`/`yes`/`on` and `0`/`false`/`no`/`off`):
      HOMEBREW_GHOSTTY_AUTO_UPDATES=1  (or HOMEBREW_AITOOLS_AUTO_UPDATES=1)
      HOMEBREW_GHOSTTY_SKIP_DEFAULTS=1 (or HOMEBREW_AITOOLS_SKIP_DEFAULTS=1)

    Installing or upgrading this cask does not modify `~/.config/ghostty`,
    coding-agent configs, or shell profile files.
  EOS
end
