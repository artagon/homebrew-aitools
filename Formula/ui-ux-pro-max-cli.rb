class UiUxProMaxCli < Formula
  desc "UI/UX design intelligence CLI, searchable database, and agent skills"
  homepage "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill"
  url "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/archive/refs/tags/v2.15.0.tar.gz"
  sha256 "633f8b71a7bea2e354ac0792ed2ffde0b7995cbf4eac2c852235e1f8f46400f6"
  license "MIT"
  revision 1
  head "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "bun" => :build
  depends_on "node"
  depends_on "python@3.13"

  def install
    cd "cli" do
      system "npm", "ci", *std_npm_args(prefix: false), "--omit=dev"
      system "bun", "build", "src/index.ts", "--outdir", "dist", "--target", "node"
    end

    libexec.install "cli/dist", "cli/assets"
    # Upstream semantic-release stamps cli/package.json only during npm publish,
    # so sync the staged manifest version to the tagged release version.
    cli_pkg = JSON.parse((buildpath/"cli/package.json").read)
    cli_pkg["version"] = version.to_s
    (libexec/"package.json").write "#{JSON.pretty_generate(cli_pkg)}\n"

    pkgshare.install "skill.json"

    apm_dir = pkgshare/"apm/#{name}"
    (apm_dir/"skills").install ".claude/skills/ui-ux-pro-max"
    (libexec/"assets/skills").children.each do |skill_dir|
      cp_r skill_dir, apm_dir/"skills"/skill_dir.basename if skill_dir.directory?
    end
    (apm_dir/"apm.yml").write <<~YAML
      name: ui-ux-pro-max
      version: "#{version}"
      description: "UI/UX design intelligence skill suite with searchable local style, palette, typography, UX, icon, chart, and stack databases."
      author: NextLevelBuilder
      license: MIT
      dependencies:
        apm: []
        mcp: []
        lsp: []
      includes:
        - skills
    YAML
    pkgshare.install_symlink apm_dir/"skills" => "skills"

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `ui-ux-pro-max-cli` (`artagon/aitools/ui-ux-pro-max-cli`)

      - **Binaries:** `uipro`, `uipro-search`
      - **Offline design database:** Bundled CSVs under `#{opt_pkgshare}/apm/#{name}/skills/ui-ux-pro-max/data/` (Python 3.13 stdlib; prefer `uipro-search "..." --json`)
      - **OpenAPM package:** `#{opt_pkgshare}/apm/#{name}` (symlink-free `apm.yml` and 7 skills)
      - **Hardening:** `uipro update` is blocked (`exit 2`); `DO_NOT_TRACK=1` and `PYTHONDONTWRITEBYTECODE=1` are set by default.
      - **Opt-in project init:** `uipro init --ai claude --offline`, `aitools-skills sync --formula ui-ux-pro-max-cli`, or `apm install -g #{opt_pkgshare}/apm/#{name}`
      - **Upgrade:** `brew upgrade artagon/aitools/ui-ux-pro-max-cli`
    MARKDOWN

    node_bin = formula_opt_bin("node")/"node"
    (bin/"uipro").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

      skip_next=0
      after_ddash=0
      for arg in "$@"; do
        if [[ "${skip_next}" -eq 1 ]]; then
          skip_next=0
          continue
        fi
        if [[ "${after_ddash}" -eq 0 ]]; then
          case "${arg}" in
            --)
              after_ddash=1
              continue
              ;;
            -h | --help | -V | --version)
              break
              ;;
            -t | --token)
              skip_next=1
              continue
              ;;
            -*)
              continue
              ;;
          esac
        fi
        if [[ "${arg}" = "update" ]]; then
          printf '%s\\n' "Error: Homebrew manages ui-ux-pro-max-cli upgrades. Run: brew upgrade artagon/aitools/ui-ux-pro-max-cli" >&2
          exit 2
        fi
        break
      done

      exec "#{node_bin}" "#{opt_libexec}/dist/index.js" "$@"
    SH
    chmod 0755, bin/"uipro"

    python_bin = formula_opt_bin("python@3.13")/"python3.13"
    (bin/"uipro-search").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
      export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
      export PYTHONUTF8="${PYTHONUTF8:-1}"
      export PYTHONDONTWRITEBYTECODE="${PYTHONDONTWRITEBYTECODE:-1}"

      exec "#{python_bin}" "#{opt_pkgshare}/apm/#{name}/skills/ui-ux-pro-max/scripts/search.py" "$@"
    SH
    chmod 0755, bin/"uipro-search"
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `uipro update`. Use:
        brew upgrade artagon/aitools/ui-ux-pro-max-cli

      Query the offline UI/UX design database directly:
        uipro-search "saas dashboard minimal" --design-system --json
        python3 #{opt_pkgshare}/skills/ui-ux-pro-max/scripts/search.py "fintech" --domain style --json

      Install skill templates into a project offline when desired:
        uipro init --ai claude --offline

      Bundled agent skills, self-contained OpenAPM package (`apm.yml` + `skills/`),
      and package agent guide are staged passively under:
        #{opt_pkgshare}/skills
        #{opt_pkgshare}/apm/#{name}
        #{opt_share}/doc/ui-ux-pro-max-cli/AGENTS.md

      This formula does not modify any agent configuration file during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s

    assert_equal version.to_s, shell_output("#{bin}/uipro --version").strip
    assert_match "brew upgrade artagon/aitools/ui-ux-pro-max-cli",
                 shell_output("#{bin}/uipro update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/ui-ux-pro-max-cli",
                 shell_output("#{bin}/uipro --token dummy update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/ui-ux-pro-max-cli",
                 shell_output("#{bin}/uipro -- update --ai claude 2>&1", 2)
    assert_match "Usage: uipro", shell_output("#{bin}/uipro -h update")

    node_bin = formula_opt_bin("node")/"node"
    probe_src = (bin/"uipro").read
    refute_nil probe_src.sub!(%Q(exec "#{node_bin}" "#{opt_libexec}/dist/index.js" "$@"), "exec /usr/bin/env")
    probe = testpath/"uipro-env-probe"
    probe.write(probe_src)
    chmod 0755, probe
    assert_match(/^DO_NOT_TRACK=1$/, shell_output("env -u DO_NOT_TRACK #{probe} --version"))

    project = testpath/"project"
    project.mkpath
    cd project do
      system bin/"uipro", "init", "--ai", "claude", "--offline"
    end
    assert_path_exists project/".claude/skills/ui-ux-pro-max/SKILL.md"
    assert_path_exists project/".claude/skills/brand/SKILL.md"

    style_result = JSON.parse(shell_output("#{bin}/uipro-search 'fintech dashboard minimal' --domain style --json"))
    assert_equal "style", style_result["domain"]
    assert_operator style_result["count"].to_i, :>=, 1

    python_bin = formula_opt_bin("python@3.13")/"python3.13"
    ds_out = shell_output(
      "#{python_bin} #{pkgshare}/skills/ui-ux-pro-max/scripts/search.py " \
      "'saas analytics dashboard' --design-system --json",
    )
    ds_result = JSON.parse(ds_out)
    assert_kind_of Hash, ds_result["design_system"]

    assert_path_exists pkgshare/"skills/ui-ux-pro-max/SKILL.md"
    assert_path_exists pkgshare/"skills/ui-ux-pro-max/scripts/search.py"
    assert_path_exists pkgshare/"skills/ui-ux-pro-max/data/styles.csv"
    assert_path_exists pkgshare/"skills/brand/SKILL.md"
    assert_path_exists pkgshare/"apm/#{name}/apm.yml"
    refute_path_exists pkgshare/"apm/#{name}/apm.lock.yaml"
    assert_path_exists pkgshare/"apm/#{name}/skills/ui-ux-pro-max/SKILL.md"
    refute_predicate pkgshare/"apm/#{name}/skills", :symlink?
    assert_path_exists doc/"AGENTS.md"
    assert_match "name: ui-ux-pro-max", (pkgshare/"apm/#{name}/apm.yml").read
    assert_match %Q(version: "#{version}"), (pkgshare/"apm/#{name}/apm.yml").read
    refute_match(/^targets:/, (pkgshare/"apm/#{name}/apm.yml").read)

    %w[.claude .codex .gemini .agents].each do |dotfile|
      refute_path_exists testpath/dotfile
    end
  end
end
