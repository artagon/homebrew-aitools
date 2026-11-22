cask "markdown-preview" do
  version "0.0.74"
  sha256 "ad62c7156391834fc64f6bdb60c06a60d0e5a0e365f8ba44e57cad39694db973"

  url "https://github.com/pluk-inc/markdown-preview/releases/download/v#{version}/Markdown-Preview.dmg"
  name "Markdown Preview"
  desc "Markdown previewer with bundled Quick Look extension"
  homepage "https://markdownpreview.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on formula: "duti"
  depends_on macos: :sequoia

  app "Markdown Preview.app"
  binary "#{appdir}/Markdown Preview.app/Contents/Resources/bin/markdown-preview", target: "mdp"
  binary "#{appdir}/Markdown Preview.app/Contents/Resources/bin/markdown-preview", target: "md-preview"
  binary "#{appdir}/Markdown Preview.app/Contents/Resources/bin/markdown-preview", target: "markdown-preview"

  postflight_steps do
    run "/bin/bash",
        args:           [
          "-euo", "pipefail", "-c",
          <<~'SH',
            homebrew_prefix="${1:-}"
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

            if env_bool "${HOMEBREW_MARKDOWN_PREVIEW_SKIP_DEFAULTS:-}" "${HOMEBREW_AITOOLS_SKIP_DEFAULTS:-}" 0; then
              exit 0
            fi

            if env_bool "${HOMEBREW_MARKDOWN_PREVIEW_AUTO_UPDATES:-}" "${HOMEBREW_AITOOLS_AUTO_UPDATES:-}" 0; then
              write_bool doc.md-preview SUEnableAutomaticChecks true
            else
              write_bool doc.md-preview SUEnableAutomaticChecks false
              write_bool doc.md-preview SUAutomaticallyUpdate false
              write_bool doc.md-preview SUSendProfileInfo false
              write_bool doc.md-preview SUHasLaunchedBefore true
            fi

            if env_bool "${HOMEBREW_MARKDOWN_PREVIEW_TELEMETRY:-}" "${HOMEBREW_AITOOLS_TELEMETRY:-}" 0; then
              write_bool doc.md-preview MarkdownPreview.shareAnonymousUsageAnalytics true
              write_bool doc.md-preview MarkdownPreview.sendAnonymousCrashReports true
            else
              write_bool doc.md-preview MarkdownPreview.shareAnonymousUsageAnalytics false
              write_bool doc.md-preview MarkdownPreview.sendAnonymousCrashReports false
            fi

            default_set_default=1
            if env_bool "${CI:-}" "" 0; then
              default_set_default=0
            fi
            if env_bool "${HOMEBREW_MARKDOWN_PREVIEW_SET_DEFAULT:-}" "${HOMEBREW_AITOOLS_SET_DEFAULT:-}" "${default_set_default}"; then
              duti_bin=""
              for candidate in "${homebrew_prefix}/bin/duti" "/opt/homebrew/bin/duti" "/usr/local/bin/duti"; do
                if [ -f "${candidate}" ] && [ -x "${candidate}" ]; then
                  duti_bin="${candidate}"
                  break
                fi
              done
              if [ -z "${duti_bin}" ]; then
                printf 'warning: duti not found; skipping default-handler registration\n' >&2
                rc=1
              else
                duti_rc=0
                if current="$("${duti_bin}" -d net.daringfireball.markdown 2>/dev/null)"; then
                  :
                else
                  duti_rc=$?
                  current=""
                fi
                current="${current#"${current%%[![:space:]]*}"}"
                current="${current%"${current##*[![:space:]]}"}"
                if [ "${duti_rc}" -eq 0 ] && [ "${current}" = "doc.md-preview" ]; then
                  :
                elif [ "${duti_rc}" -eq 0 ] || [ "${duti_rc}" -eq 1 ]; then
                  if ! "${duti_bin}" -s doc.md-preview net.daringfireball.markdown all; then
                    printf 'warning: duti failed to set default handler for net.daringfireball.markdown\n' >&2
                    rc=1
                  fi
                else
                  printf 'warning: duti -d exited with status %s; skipping default-handler update\n' "${duti_rc}" >&2
                  rc=1
                fi
              fi
            fi

            exit "${rc}"
          SH
          "_",
          "{{HOMEBREW_PREFIX}}"
        ],
        writable_paths: [
          "Library/Preferences",
          "Library/Containers/doc.md-preview/Data/Library/Preferences",
        ],
        writable_base:  :home,
        must_succeed:   false
  end

  uninstall quit: "doc.md-preview"

  zap trash: [
    "~/Library/Application Scripts/5P3TSMNV42.doc.md-preview",
    "~/Library/Application Scripts/doc.md-preview",
    "~/Library/Application Scripts/doc.md-preview.quick-look",
    "~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/doc.md-preview.sfl*",
    "~/Library/Caches/doc.md-preview",
    "~/Library/Containers/doc.md-preview",
    "~/Library/Containers/doc.md-preview.quick-look",
    "~/Library/Group Containers/5P3TSMNV42.doc.md-preview",
    "~/Library/HTTPStorages/doc.md-preview",
    "~/Library/Preferences/doc.md-preview.plist",
  ]

  caveats <<~EOS
    Homebrew manages this installation; upgrade with:
      brew upgrade --cask artagon/aitools/markdown-preview

    This cask links the `mdp`, `md-preview`, and `markdown-preview` CLI
    commands. Default `postflight_steps` disable Sparkle auto-updates, disable
    usage analytics and crash reporting, and register `doc.md-preview` as the
    default handler for `net.daringfireball.markdown` (`.md` / `.markdown`,
    skipped when already set or when `CI` is truthy). On macOS 15+, changing
    the default handler displays one macOS confirmation dialog.

    Override install-time settings with `HOMEBREW_*` environment flags (`brew`
    strips non-`HOMEBREW_*` variables; per-cask flags override tap-wide ones;
    accepted values are `1`/`true`/`yes`/`on` and `0`/`false`/`no`/`off`):
      HOMEBREW_MARKDOWN_PREVIEW_AUTO_UPDATES=1  (or HOMEBREW_AITOOLS_AUTO_UPDATES=1)
      HOMEBREW_MARKDOWN_PREVIEW_TELEMETRY=1     (or HOMEBREW_AITOOLS_TELEMETRY=1)
      HOMEBREW_MARKDOWN_PREVIEW_SET_DEFAULT=0   (or HOMEBREW_AITOOLS_SET_DEFAULT=0)
      HOMEBREW_MARKDOWN_PREVIEW_SKIP_DEFAULTS=1 (or HOMEBREW_AITOOLS_SKIP_DEFAULTS=1)

    Installing or upgrading this cask does not modify coding-agent configs or
    shell profile files.
  EOS
end
