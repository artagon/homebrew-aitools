class AgencyAgents < Formula
  desc "Specialized AI agent persona catalog and multi-tool installer"
  homepage "https://github.com/msitarzewski/agency-agents"
  url "https://github.com/msitarzewski/agency-agents/archive/8ae6164602c95ca78828b148b9052460ee426885.tar.gz"
  version "2026.11.09"
  sha256 "2e1b4675c3612595c8aaca808e0c2e3291464f305db9d98828dea402997a6c88"
  license "MIT"
  head "https://github.com/msitarzewski/agency-agents.git", branch: "main"

  livecheck do
    skip "Upstream repository does not publish versioned release tags"
  end

  def install
    catalog_entries = buildpath.children.reject do |entry|
      entry.basename.to_s.start_with?(".")
    end
    pkgshare.install catalog_entries

    # Direct converted integration outputs to a user-writable cache directory
    # so runtime conversion never attempts to write into the read-only Cellar.
    inreplace pkgshare/"scripts/convert.sh",
              'OUT_DIR="$REPO_ROOT/integrations"',
              'OUT_DIR="${AGENCY_INTEGRATIONS_DIR:-$REPO_ROOT/integrations}"'

    inreplace pkgshare/"scripts/install.sh" do |s|
      s.gsub! 'INTEGRATIONS="$REPO_ROOT/integrations"',
              'INTEGRATIONS="${AGENCY_INTEGRATIONS_DIR:-$REPO_ROOT/integrations}"'
      s.gsub! 'if [[ "$link_to" == "$REPO_ROOT/"* ]]; then',
              'if [[ "$link_to" == "$REPO_ROOT/"* || "$link_to" == "$INTEGRATIONS/"* ]]; then'
      s.gsub! 'if "$SCRIPT_DIR/convert.sh" --tool "$tool" >/dev/null 2>&1; then',
              'if "$SCRIPT_DIR/convert.sh" --tool "$tool" --out "$INTEGRATIONS" >/dev/null 2>&1; then'
      s.gsub! <<~SH, <<~SH
        check_integrations() {
          if [[ ! -d "$INTEGRATIONS" ]]; then
            err "integrations/ not found. Run ./scripts/convert.sh first."
            exit 1
          fi
        }
      SH
        check_integrations() {
          :
        }
      SH
    end

    chmod 0755, pkgshare/"scripts/install.sh"
    chmod 0755, pkgshare/"scripts/convert.sh"

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `agency-agents` (`artagon/aitools/agency-agents`)

      - **Binaries:** `agency-agents`, `agency-agents-install`, `agency-agents-convert`
      - **Passive catalog:** `#{opt_pkgshare}` (18 divisions, `divisions.json`, `tools.json`, `strategy/`, `examples/`, `scripts/`)
      - **Conversion cache:** `${XDG_CACHE_HOME:-~/.cache}/agency-agents/integrations/#{version}` (override with `AGENCY_INTEGRATIONS_DIR` or `--out`; Cellar stays read-only)
      - **Hardening:** Exports `DO_NOT_TRACK=1`, blocks `update`/`self-update`/`upgrade` (`exit 2`), and never modifies agent dotfiles on install.
      - **Opt-in usage:** `agency-agents list teams`, `agency-agents-install --tool claude-code --division engineering --dry-run`
      - **Desktop app:** `brew install --cask artagon/aitools/agency-agents`
      - **Upgrade:** `brew upgrade artagon/aitools/agency-agents`
    MARKDOWN

    (bin/"agency-agents-install").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK=1
      export AGENCY_INTEGRATIONS_DIR="${AGENCY_INTEGRATIONS_DIR:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/agency-agents/integrations/#{version}}"

      seen_pos=0
      skip_next=0
      for arg in ${1+"$@"}; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        case "${arg}" in
          --)
            break
            ;;
          -h | --help | -V | --version)
            if [[ "${seen_pos}" -eq 0 ]]; then
              break
            fi
            ;;
          --tool | --division | --agent | --agents-file | --path | --jobs | --list)
            skip_next=1
            ;;
          -*)
            ;;
          *)
            if [[ "${seen_pos}" -eq 0 ]]; then
              seen_pos=1
              case "${arg}" in
                update | self-update | upgrade)
                  printf '%s\\n' "Error: Homebrew manages agency-agents upgrades. Run: brew upgrade artagon/aitools/agency-agents" >&2
                  exit 2
                  ;;
                *)
                  ;;
              esac
            fi
            ;;
        esac
      done

      exec /bin/bash "#{opt_pkgshare}/scripts/install.sh" ${1+"$@"}
    SH
    chmod 0755, bin/"agency-agents-install"

    (bin/"agency-agents-convert").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK=1
      export AGENCY_INTEGRATIONS_DIR="${AGENCY_INTEGRATIONS_DIR:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/agency-agents/integrations/#{version}}"

      seen_pos=0
      skip_next=0
      for arg in ${1+"$@"}; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        case "${arg}" in
          --)
            break
            ;;
          -h | --help | -V | --version)
            if [[ "${seen_pos}" -eq 0 ]]; then
              break
            fi
            ;;
          --tool | --out | --jobs)
            skip_next=1
            ;;
          -*)
            ;;
          *)
            if [[ "${seen_pos}" -eq 0 ]]; then
              seen_pos=1
              case "${arg}" in
                update | self-update | upgrade)
                  printf '%s\\n' "Error: Homebrew manages agency-agents upgrades. Run: brew upgrade artagon/aitools/agency-agents" >&2
                  exit 2
                  ;;
                *)
                  ;;
              esac
            fi
            ;;
        esac
      done

      exec /bin/bash "#{opt_pkgshare}/scripts/convert.sh" ${1+"$@"}
    SH
    chmod 0755, bin/"agency-agents-convert"

    (bin/"agency-agents").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK=1

      usage() {
        cat <<'EOF'
      Usage: agency-agents <command> [args...]

      Commands:
        install [args...]         Run the opt-in multi-tool installer (agency-agents-install)
        convert [args...]         Convert personas into tool formats (agency-agents-convert)
        list [tools|teams|agents] List supported tools, teams/divisions, or agents
        path                      Print the staged catalog directory
        --version, -v             Print the packaged version
        --help, -h                Show this help
      EOF
      }

      if [[ "$#" -eq 0 ]]; then
        usage
        exit 0
      fi

      cmd="$1"
      shift

      case "${cmd}" in
        -v | --version | version)
          printf '%s\\n' "agency-agents #{version}"
          ;;
        -h | --help | help)
          usage
          ;;
        path | --path)
          printf '%s\\n' "#{opt_pkgshare}"
          ;;
        list | --list)
          exec "#{opt_bin}/agency-agents-install" --list ${1+"$@"}
          ;;
        install)
          exec "#{opt_bin}/agency-agents-install" ${1+"$@"}
          ;;
        convert)
          exec "#{opt_bin}/agency-agents-convert" ${1+"$@"}
          ;;
        update | self-update | upgrade)
          printf '%s\\n' "Error: Homebrew manages agency-agents upgrades. Run: brew upgrade artagon/aitools/agency-agents" >&2
          exit 2
          ;;
        *)
          printf 'Error: unknown command: %s\\n' "${cmd}" >&2
          usage >&2
          exit 2
          ;;
      esac
    SH
    chmod 0755, bin/"agency-agents"
  end

  def caveats
    <<~EOS
      The Agency persona catalog, manifests (`divisions.json`, `tools.json`),
      playbooks, examples, scripts, and package agent guide are staged passively under:
        #{opt_pkgshare}
        #{opt_share}/doc/agency-agents/AGENTS.md

      Installing or upgrading this formula does not modify `~/.claude*`,
      `~/.codex*`, `~/.gemini*`, `~/.config/*`, or any coding-agent config.

      Inspect or opt in explicitly with:
        agency-agents list teams
        agency-agents list tools
        agency-agents path
        agency-agents-install --tool claude-code --division engineering --dry-run
        agency-agents-convert --tool codex --out /path/to/output

      Converted tool integrations default to a user-writable cache under
      `${XDG_CACHE_HOME:-~/.cache}/agency-agents/integrations/#{version}`
      (override with `AGENCY_INTEGRATIONS_DIR` or `--out`).

      Homebrew manages upgrades; do not run self-updaters. Upgrade with:
        brew upgrade artagon/aitools/agency-agents
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s

    assert_match "agency-agents #{version}", shell_output("#{bin}/agency-agents --version")
    assert_match "Usage: agency-agents", shell_output("#{bin}/agency-agents --help")
    assert_equal opt_pkgshare.to_s, shell_output("#{bin}/agency-agents path").strip

    assert_match "brew upgrade artagon/aitools/agency-agents",
                 shell_output("#{bin}/agency-agents update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agency-agents",
                 shell_output("#{bin}/agency-agents self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agency-agents",
                 shell_output("#{bin}/agency-agents-install update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/agency-agents",
                 shell_output("#{bin}/agency-agents-convert upgrade 2>&1", 2)

    teams_out = shell_output("#{bin}/agency-agents-install --list teams")
    assert_match "engineering", teams_out
    assert_match "research", teams_out
    assert_match "security", teams_out

    tools_out = shell_output("#{bin}/agency-agents list tools")
    assert_match "claude-code", tools_out
    assert_match "codex", tools_out
    assert_match "cursor", tools_out

    assert_match "Usage:", shell_output("#{bin}/agency-agents-convert --help")

    conv_dir = testpath/"conv"
    system bin/"agency-agents-convert", "--tool", "aider", "--out", conv_dir.to_s
    assert_path_exists conv_dir/"aider/CONVENTIONS.md"

    out_dir = testpath/"claude-agents"
    system bin/"agency-agents-install",
           "--tool", "claude-code",
           "--division", "research",
           "--path", out_dir.to_s
    assert_path_exists out_dir/"research-synthesist.md"

    # Verify --no-convert looks in the user-writable cache (not the Cellar)
    # and fails cleanly when integrations have not been generated yet.
    codex_dir = testpath/"codex"
    assert_match "integrations/codex missing",
                 shell_output("#{bin}/agency-agents-install --tool codex --no-convert --path #{codex_dir} 2>&1", 1)

    assert_path_exists pkgshare/"divisions.json"
    assert_path_exists pkgshare/"tools.json"
    assert_path_exists pkgshare/"README.md"
    assert_path_exists pkgshare/"LICENSE"
    assert_path_exists pkgshare/"examples/README.md"
    assert_path_exists pkgshare/"strategy/runbooks.json"
    assert_path_exists pkgshare/"scripts/install.sh"
    assert_path_exists pkgshare/"scripts/convert.sh"
    assert_path_exists pkgshare/"scripts/lib.sh"
    assert_path_exists doc/"AGENTS.md"

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".config"
  end
end
