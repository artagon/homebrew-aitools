class AgentSkills < Formula
  desc "Production-grade software engineering skills and checklists for AI agents"
  homepage "https://github.com/addyosmani/agent-skills"
  url "https://github.com/addyosmani/agent-skills/archive/refs/tags/0.6.18.tar.gz"
  sha256 "68d94627bffa6cc0689ba26d4bcf833ac1c6b0049c2abec1a7261faca440819d"
  license "MIT"
  revision 1
  head "https://github.com/addyosmani/agent-skills.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/agent-skills-0.6.18_1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "d04ff65a94b2e919569172f0ffaf333812c2f9320f6a576e5ec9a344e8db3675"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "2d361031293ce8ead2564fafcac073ecd2ec573132aae359d205702a41f217c9"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "3f658ff370daabb495f4ce498d8c5915b751063b5edea0805b6a7cc3d3d1ebe9"
  end

  def install
    pkgshare.install "skills", "agents", "references", "commands", "hooks", "docs",
                     "plugin.json", "AGENTS.md", "CLAUDE.md",
                     ".agents", ".claude", ".claude-plugin", ".codex-plugin", ".gemini", ".opencode"

    apm_dir = pkgshare/"apm/#{name}"
    apm_dir.mkpath
    cp_r pkgshare/"skills", apm_dir/"skills"
    (apm_dir/"apm.yml").write <<~YAML
      name: addyosmani-agent-skills
      version: "#{version}"
      description: "Production-grade engineering skills for AI coding agents covering the full software development lifecycle from spec to ship."
      author: Addy Osmani
      license: MIT
      dependencies:
        apm: []
        mcp: []
        lsp: []
      includes:
        - skills
    YAML

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `agent-skills` (`artagon/aitools/agent-skills`)

      - **Binary:** `addy-agent-skills` (`--list`, `--path`, `--skills-path`, `--apm-path`, `--version`)
      - **Passive assets:** `#{opt_pkgshare}` (26 skills, 5 review personas in `agents/`, 7 checklists in `references/`, 10 TOML `commands/`, passive `hooks/`, native `.claude-plugin`/`.codex-plugin` manifests)
      - **OpenAPM package:** `#{opt_pkgshare}/apm/#{name}` (symlink-free `apm.yml` and `skills/`)
      - **Opt-in activation:** `aitools-skills sync --formula agent-skills`, `apm install -g "$(addy-agent-skills --apm-path)"`, or `claude --plugin-dir "$(addy-agent-skills --path)"`
      - **Hardening:** Zero hooks activated and zero dotfiles written during install; `DO_NOT_TRACK=1` exported by default.
      - **Upgrade:** `brew upgrade artagon/aitools/agent-skills`
    MARKDOWN

    (bin/"addy-agent-skills").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

      readonly pkgshare="#{opt_pkgshare}"
      readonly apm_dir="#{opt_pkgshare}/apm/#{name}"
      readonly pkg_version="#{version}"

      usage() {
        cat <<'EOF'
      Usage: addy-agent-skills [OPTIONS]

      Inspect passively staged Addy Osmani Agent Skills installed via Homebrew.

      Options:
        --list         List bundled skill names
        --path         Print root pkgshare path (skills, agents, references, plugins)
        --skills-path  Print bundled skills directory path
        --apm-path     Print self-contained OpenAPM package path (apm.yml + skills/)
        -V, --version  Print installed package version
        -h, --help     Show this help message
      EOF
      }

      list_skills() {
        local skill_md="" skill_dir=""
        local -a names=()
        shopt -s nullglob
        for skill_md in "${pkgshare}/skills"/*/SKILL.md; do
          [[ -f "${skill_md}" ]] || continue
          skill_dir="$(dirname "${skill_md}")"
          names+=("$(basename "${skill_dir}")")
        done
        shopt -u nullglob
        if [[ "${#names[@]}" -gt 0 ]]; then
          LC_ALL=C printf '%s\\n' "${names[@]}" | LC_ALL=C sort
        fi
      }

      action=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -V|--version)
            action="version"
            ;;
          --list)
            action="list"
            ;;
          --path)
            action="path"
            ;;
          --skills-path)
            action="skills-path"
            ;;
          --apm-path)
            action="apm-path"
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          --)
            shift
            if [[ $# -gt 0 ]]; then
              printf 'Error: unexpected positional argument: %s\\n' "$1" >&2
              usage >&2
              exit 2
            fi
            break
            ;;
          *)
            printf 'Error: unknown option: %s\\n' "$1" >&2
            usage >&2
            exit 2
            ;;
        esac
        shift
      done

      case "${action}" in
        version)
          printf '%s\\n' "${pkg_version}"
          ;;
        list)
          list_skills
          ;;
        path)
          printf '%s\\n' "${pkgshare}"
          ;;
        skills-path)
          printf '%s\\n' "${pkgshare}/skills"
          ;;
        apm-path)
          printf '%s\\n' "${apm_dir}"
          ;;
        *)
          usage
          ;;
      esac
    SH
    chmod 0755, bin/"addy-agent-skills"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades via:
        brew upgrade artagon/aitools/agent-skills

      Inspect installed skills and asset locations:
        addy-agent-skills --list
        addy-agent-skills --path
        addy-agent-skills --apm-path

      Portable skills, agent personas, checklists, native plugin manifests,
      the self-contained OpenAPM package (`apm.yml` + `skills/`), and
      package agent guide are staged passively under:
        #{opt_pkgshare}/skills
        #{opt_pkgshare}/agents
        #{opt_pkgshare}/references
        #{opt_pkgshare}/apm/#{name}
        #{opt_share}/doc/agent-skills/AGENTS.md

      This formula does not activate hooks or modify any agent configuration file
      during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    assert_equal version.to_s, shell_output("#{bin}/addy-agent-skills --version").strip
    assert_equal opt_pkgshare.to_s, shell_output("#{bin}/addy-agent-skills --path").strip
    assert_equal (opt_pkgshare/"skills").to_s, shell_output("#{bin}/addy-agent-skills --skills-path").strip
    assert_equal (opt_pkgshare/"apm/#{name}").to_s, shell_output("#{bin}/addy-agent-skills --apm-path").strip
    assert_match "Usage: addy-agent-skills", shell_output("#{bin}/addy-agent-skills --help")

    listed = shell_output("#{bin}/addy-agent-skills --list").lines.map(&:strip).reject(&:empty?)
    assert_operator listed.length, :>=, 26
    assert_includes listed, "spec-driven-development"
    assert_includes listed, "test-driven-development"
    assert_includes listed, "using-agent-skills"

    assert_match "unknown option", shell_output("#{bin}/addy-agent-skills --unknown 2>&1", 2)
    assert_match "unexpected positional argument", shell_output("#{bin}/addy-agent-skills -- extra 2>&1", 2)

    assert_path_exists pkgshare/"skills/spec-driven-development/SKILL.md"
    assert_path_exists pkgshare/"agents/code-reviewer.md"
    assert_path_exists pkgshare/"references/definition-of-done.md"
    assert_path_exists pkgshare/"commands/spec.toml"
    assert_path_exists pkgshare/"hooks/session-start.sh"
    assert_path_exists pkgshare/"plugin.json"
    assert_path_exists pkgshare/".claude-plugin/plugin.json"
    assert_path_exists pkgshare/".codex-plugin/plugin.json"
    assert_path_exists pkgshare/"apm/#{name}/apm.yml"
    refute_path_exists pkgshare/"apm/#{name}/apm.lock.yaml"
    assert_path_exists pkgshare/"apm/#{name}/skills/spec-driven-development/SKILL.md"
    refute_predicate pkgshare/"apm/#{name}/skills", :symlink?
    assert_path_exists doc/"AGENTS.md"
    assert_match "name: addyosmani-agent-skills", (pkgshare/"apm/#{name}/apm.yml").read
    assert_match %Q(version: "#{version}"), (pkgshare/"apm/#{name}/apm.yml").read
    refute_match(/^targets:/, (pkgshare/"apm/#{name}/apm.yml").read)

    %w[.claude .codex .gemini .agents].each do |dotfile|
      refute_path_exists testpath/dotfile
    end
  end
end
