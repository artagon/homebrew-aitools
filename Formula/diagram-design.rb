class DiagramDesign < Formula
  desc "Editorial HTML and SVG diagram skill across 52 types for AI coding agents"
  homepage "https://github.com/cathrynlavery/diagram-design"
  url "https://github.com/cathrynlavery/diagram-design/archive/67dbb00176980741a909c84c124f86ef91bbf546.tar.gz"
  version "2.6.178"
  sha256 "f5c9d5f9dc11a5ad17296e1076117094c89e1dc7ecb4f93a10db1e1109b9e56c"
  license "MIT"
  revision 1
  head "https://github.com/cathrynlavery/diagram-design.git", branch: "main"

  livecheck do
    skip "Upstream publishes versioned commits on main without git tags"
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/diagram-design-2.6.178_1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "64942c8b8dc34d5d225248a806c915fbd1f80ed8b7b86afec782a92db27c4888"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "309038104da97755498e60b5fa1227597714beeac2a03547627e5e985a2f435e"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "890e1c38e2367d11d1bcd2d363cd177af811855c60501c3e76652df69cf22737"
  end

  depends_on "python@3.13"

  def install
    prefix.install "LICENSE", "THIRD_PARTY_LICENSES.md"
    doc.install "README.md", "CHANGELOG.md", "PRIVACY.md", "SECURITY.md"

    pkgshare.install ".agents", ".claude-plugin", ".codex-plugin", ".factory-plugin",
                     ".qoder-plugin", "assets", "commands", "prompts", "skills"
    cp doc/"README.md", pkgshare/"README.md"

    apm_dir = pkgshare/"apm/#{name}"
    (apm_dir/"skills").mkpath
    cp_r pkgshare/"skills/diagram-design", apm_dir/"skills/diagram-design"
    (apm_dir/"apm.yml").write <<~YAML
      name: diagram-design
      version: "#{version}"
      description: "Editorial diagram design skill for self-contained HTML and SVG diagrams across 52 diagram types."
      author: Cathryn Lavery
      license: MIT
      dependencies:
        apm: []
        mcp: []
        lsp: []
      includes:
        - skills
    YAML

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `diagram-design` (`artagon/aitools/diagram-design`)

      - **Binary:** `diagram-design` (`--list`, `--path`, `--skill-path`, `--apm-path`, `self-check [--offline] <file>`)
      - **Passive assets:** `#{opt_pkgshare}` (52 HTML/SVG diagram types, stdlib Python 3.13 scripts, native `.claude-plugin`/`.codex-plugin`/`.factory-plugin`/`.qoder-plugin` manifests)
      - **OpenAPM package:** `#{opt_pkgshare}/apm/#{name}` (symlink-free `apm.yml` and `skills/diagram-design/`)
      - **Offline font rule:** Templates link Google Fonts by default; run `diagram-design self-check --offline <file>` to enforce system-font-only zero-egress diagrams.
      - **Hardening:** Exports `DO_NOT_TRACK=1`, `PYTHONNOUSERSITE=1`, `PYTHONUTF8=1`, `PYTHONDONTWRITEBYTECODE=1`, blocks `update`/`self-update`/`upgrade` (`exit 2`).
      - **Upgrade:** `brew upgrade artagon/aitools/diagram-design`
    MARKDOWN

    python_bin = formula_opt_bin("python@3.13")/"python3.13"
    (bin/"diagram-design").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
      export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
      export PYTHONUTF8="${PYTHONUTF8:-1}"
      export PYTHONDONTWRITEBYTECODE="${PYTHONDONTWRITEBYTECODE:-1}"

      readonly VERSION="#{version}"
      readonly PKGSHARE="#{opt_pkgshare}"
      readonly APM_DIR="#{opt_pkgshare}/apm/#{name}"
      readonly SKILL_DIR="#{opt_pkgshare}/skills/diagram-design"
      readonly PYTHON_BIN="#{python_bin}"

      usage() {
        cat <<'EOF'
      Usage: diagram-design [OPTIONS]
             diagram-design self-check [--offline] <file> [...]

      Inspect staged diagram-design assets and run offline HTML/SVG self-checks.

      Options:
        --version, -V     Print formula version
        --path            Print staged plugin root (pkgshare)
        --skill-path      Print staged Agent Skill directory
        --apm-path        Print staged OpenAPM package directory
        --list            List bundled diagram types, commands, and helper scripts
        --help, -h        Show this help message

      Subcommands:
        self-check        Run skills/diagram-design/scripts/self_check.py on HTML files
      EOF
      }

      require_no_extra_args() {
        if [[ "$#" -gt 1 ]]; then
          printf 'Error: unexpected argument for %s: %s\\n' "$1" "$2" >&2
          usage >&2
          exit 2
        fi
      }

      list_assets() {
        local ref="" name="" cmd="" script=""
        printf 'Plugin root: %s\\n' "${PKGSHARE}"
        printf 'Skill dir:   %s\\n' "${SKILL_DIR}"
        printf 'OpenAPM dir: %s\\n' "${APM_DIR}"
        printf '\\nDiagram types:\\n'
        shopt -s nullglob
        for ref in "${SKILL_DIR}/references"/type-*.md; do
          name="${ref##*/type-}"
          printf '  %s\\n' "${name%.md}"
        done
        printf '\\nCommands:\\n'
        for cmd in "${PKGSHARE}/commands"/*.md; do
          name="${cmd##*/}"
          printf '  %s\\n' "${name%.md}"
        done
        printf '\\nHelper scripts:\\n'
        for script in "${SKILL_DIR}/scripts"/*.py; do
          printf '  %s\\n' "${script##*/}"
        done
        shopt -u nullglob
      }

      if [[ "$#" -eq 0 ]]; then
        usage >&2
        exit 2
      fi

      after_ddash=0
      if [[ "$1" = "--" ]]; then
        after_ddash=1
        shift
        if [[ "$#" -eq 0 ]]; then
          usage >&2
          exit 2
        fi
      fi

      if [[ "${after_ddash}" -eq 0 ]]; then
        case "$1" in
          -h | --help)
            require_no_extra_args "$@"
            usage
            exit 0
            ;;
          -V | --version)
            require_no_extra_args "$@"
            printf 'diagram-design %s\\n' "${VERSION}"
            exit 0
            ;;
          --path)
            require_no_extra_args "$@"
            printf '%s\\n' "${PKGSHARE}"
            exit 0
            ;;
          --skill-path)
            require_no_extra_args "$@"
            printf '%s\\n' "${SKILL_DIR}"
            exit 0
            ;;
          --apm-path)
            require_no_extra_args "$@"
            printf '%s\\n' "${APM_DIR}"
            exit 0
            ;;
          --list)
            require_no_extra_args "$@"
            list_assets
            exit 0
            ;;
          -*)
            printf 'Error: unknown option: %s\\n' "$1" >&2
            usage >&2
            exit 2
            ;;
          *)
            ;;
        esac
      fi

      case "$1" in
        help)
          require_no_extra_args "$@"
          usage
          exit 0
          ;;
        version)
          require_no_extra_args "$@"
          printf 'diagram-design %s\\n' "${VERSION}"
          exit 0
          ;;
        self-check)
          shift
          exec "${PYTHON_BIN}" "${SKILL_DIR}/scripts/self_check.py" "$@"
          ;;
        update | self-update | upgrade)
          printf '%s\\n' "Error: Homebrew manages diagram-design upgrades. Run: brew upgrade artagon/aitools/diagram-design" >&2
          exit 2
          ;;
        *)
          printf 'Error: unknown command: %s\\n' "$1" >&2
          usage >&2
          exit 2
          ;;
      esac
    SH
    chmod 0755, bin/"diagram-design"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run in-place self-updaters. Use:
        brew upgrade artagon/aitools/diagram-design

      Run offline diagram HTML/SVG self-checks directly:
        diagram-design --list
        diagram-design self-check --offline path/to/diagram.html

      Bundled HTML templates reference Google Fonts by default when opened in a
      browser; pass `--offline` to `diagram-design self-check` to enforce
      system-font-only diagrams with zero external requests.

      Bundled stdlib helper scripts (`self_check.py`, `verify_geometry.py`,
      `export_svg.py`, and draw.io/Mermaid/Excalidraw/PlantUML extractors) use
      Homebrew Python 3.13. Optional PNG/PDF rasterization (`export_png.py`,
      `export_pdf.py`) requires Playwright if explicitly invoked.

      Passive multi-agent plugin assets (Claude Code, Codex, Factory, Qoder, Pi),
      the Agent Skill, self-contained OpenAPM package (`apm.yml` + `skills/`),
      and package agent guide are staged under:
        #{opt_pkgshare}
        #{opt_pkgshare}/skills/diagram-design
        #{opt_pkgshare}/apm/#{name}
        #{opt_share}/doc/diagram-design/AGENTS.md

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    assert_equal "diagram-design #{version}", shell_output("#{bin}/diagram-design --version").strip
    assert_match "Usage: diagram-design", shell_output("#{bin}/diagram-design --help")
    assert_equal opt_pkgshare.to_s, shell_output("#{bin}/diagram-design --path").strip
    assert_equal (opt_pkgshare/"skills/diagram-design").to_s,
                 shell_output("#{bin}/diagram-design --skill-path").strip
    assert_equal (opt_pkgshare/"apm/#{name}").to_s, shell_output("#{bin}/diagram-design --apm-path").strip

    listed = shell_output("#{bin}/diagram-design --list")
    assert_match "flowchart", listed
    assert_match "sequence", listed
    assert_match "export-diagram", listed
    assert_match "self_check.py", listed

    assert_match "brew upgrade artagon/aitools/diagram-design",
                 shell_output("#{bin}/diagram-design update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/diagram-design",
                 shell_output("#{bin}/diagram-design -- self-update 2>&1", 2)
    assert_match "unknown command: --version",
                 shell_output("#{bin}/diagram-design -- --version 2>&1", 2)

    probe_src = (bin/"diagram-design").read
    refute_nil probe_src.sub!(
      'exec "${PYTHON_BIN}" "${SKILL_DIR}/scripts/self_check.py" "$@"',
      "exec /usr/bin/env",
    )
    probe = testpath/"dd-env-probe"
    probe.write(probe_src)
    chmod 0755, probe
    default_env = shell_output(
      "env -u DO_NOT_TRACK -u PYTHONNOUSERSITE -u PYTHONUTF8 -u PYTHONDONTWRITEBYTECODE #{probe} self-check",
    )
    assert_match(/^DO_NOT_TRACK=1$/, default_env)
    assert_match(/^PYTHONNOUSERSITE=1$/, default_env)
    assert_match(/^PYTHONUTF8=1$/, default_env)
    assert_match(/^PYTHONDONTWRITEBYTECODE=1$/, default_env)

    example = pkgshare/"skills/diagram-design/assets/example-flowchart.html"
    assert_match(/^OK /, shell_output("#{bin}/diagram-design self-check #{example}"))
    assert_match "Google Fonts",
                 shell_output("#{bin}/diagram-design self-check --offline #{example}", 1)

    fixture = testpath/"smoke.html"
    fixture.write <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>Smoke Diagram</title>
        <style>
          body { font-family: system-ui, sans-serif; background: #f5f5f5; color: #2d3142; }
        </style>
      </head>
      <body>
        <svg viewBox="0 0 640 240" xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="smoke-title smoke-desc">
          <title id="smoke-title">Smoke Flow</title>
          <desc id="smoke-desc">Minimal two-node flow used to verify offline diagram self-checks.</desc>
          <rect x="40" y="70" width="180" height="80" fill="#ffffff" stroke="#2d3142" stroke-width="1.5"/>
          <text x="130" y="115" text-anchor="middle" font-size="16" fill="#2d3142">Input</text>
          <line x1="220" y1="110" x2="400" y2="110" stroke="#4f5d75" stroke-width="1.5"/>
          <rect x="400" y="70" width="180" height="80" fill="#ffffff" stroke="#bf4520" stroke-width="1.5"/>
          <text x="490" y="115" text-anchor="middle" font-size="16" fill="#2d3142">Output</text>
        </svg>
      </body>
      </html>
    HTML
    assert_match(/^OK /, shell_output("#{bin}/diagram-design self-check --offline #{fixture}"))

    assert_path_exists prefix/"LICENSE"
    assert_path_exists prefix/"THIRD_PARTY_LICENSES.md"
    assert_path_exists doc/"PRIVACY.md"
    assert_path_exists doc/"AGENTS.md"

    skill_md = pkgshare/"skills/diagram-design/SKILL.md"
    assert_path_exists skill_md
    assert_match(/^name: diagram-design$/, skill_md.read)
    assert_path_exists pkgshare/"skills/diagram-design/scripts/self_check.py"
    assert_path_exists pkgshare/"commands/export-diagram.md"
    assert_path_exists pkgshare/"prompts/doctor.md"
    assert_path_exists pkgshare/"assets/logo.png"
    assert_path_exists pkgshare/".agents/plugins/marketplace.json"

    %w[.claude-plugin .codex-plugin .factory-plugin .qoder-plugin].each do |dir|
      manifest = pkgshare/dir/"plugin.json"
      assert_path_exists manifest
      assert_equal version.to_s, JSON.parse(manifest.read)["version"]
    end

    apm_yml = pkgshare/"apm/#{name}/apm.yml"
    apm_lock = pkgshare/"apm/#{name}/apm.lock.yaml"
    apm_skill = pkgshare/"apm/#{name}/skills/diagram-design/SKILL.md"
    assert_path_exists apm_yml
    refute_path_exists apm_lock
    assert_path_exists apm_skill
    refute_predicate pkgshare/"apm/#{name}/skills", :symlink?
    refute_predicate pkgshare/"apm/#{name}/skills/diagram-design", :symlink?
    assert_match(/^name: diagram-design$/, apm_yml.read)
    assert_match(/^version: "#{Regexp.escape(version.to_s)}"$/, apm_yml.read)
    refute_match(/^targets:/, apm_yml.read)

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
    refute_path_exists testpath/".diagram-design"
  end
end
