class AitoolsSkills < Formula
  desc "Offline-first Homebrew agent skill registrar for artagon/aitools"
  homepage "https://github.com/artagon/aitools-skills"
  url "https://github.com/artagon/aitools-skills/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "eb1c42290c05eadc53bff3f02805e02376874bd911860f881e800e4ba78a76f4"
  license "Apache-2.0"
  head "https://github.com/artagon/aitools-skills.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/aitools-skills-0.1.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "1d7e938556b95319e365e08bf20130c09ee300b02a0496f39a35fef6c24f7b4a"
    sha256 cellar: :any,                 arm64_linux:  "96f2a488f884250af06d2172eeb278f1a43f107010e93e1071c9ed7db1e498cb"
    sha256 cellar: :any,                 x86_64_linux: "a24eede76cef50df816833433a49bfc00cd37995b8a007f669b0597a6d274a13"
  end

  depends_on "rust" => :build

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args
    bin.install_symlink "aitools-skills" => "brew-aitools-skills"

    with_env(HOME: buildpath.to_s, XDG_CONFIG_HOME: (buildpath/".config").to_s) do
      generate_completions_from_executable(bin/"aitools-skills", "completions")
      system bin/"aitools-skills", "__generate_man", "--out-dir", buildpath/"man"
      man1.install Dir[buildpath/"man/*.1"]
    end

    (doc/"AGENTS.md").write <<~MARKDOWN
      # `aitools-skills` (`artagon/aitools/aitools-skills`)

      - **Binary:** `aitools-skills` (also invocable as `brew aitools-skills` via `bin/brew-aitools-skills` when `$(brew --prefix)/bin` is on `PATH`)
      - **Discovery:** Scans installed `artagon/aitools` formulae dynamically via `$(brew --prefix)/opt/*/INSTALL_RECEIPT.json` without dereferencing `opt/` symlinks into versioned `Cellar/` paths
      - **Backends (`--backend auto|apm|symlink`):**
        - `symlink`: Zero-dependency offline backend creating stable `opt_pkgshare` symlinks with an XDG ownership ledger
        - `apm`: Optional OpenAPM (`brew install apm`) integration reconciling `apm.yml` `targets:` for lockfiles and `apm audit --ci`
        - `auto`: Uses OpenAPM when `apm` is on `PATH` and routes unsupported/legacy targets cleanly through native symlinks
      - **Fail-closed guarantees:** Preflight blocks skill-name collisions, foreign symlinks, symlinked ancestors, unmanaged directories (unless `--force`), and remote `apm.yml` dependencies under `--offline` before mutating disk; `update`/`self-update`/`upgrade` are blocked (`exit 2`); read-only commands (`list`, `status`, `diff`, `doctor`) never write dotfiles
      - **Subcommands:** `list`, `status`, `diff`, `sync`, `prune`, `uninstall`, `audit`, `doctor`, `completions` (all emit deterministic JSON v1 with `--json` and support `--dry-run`)
      - **Upgrade:** `brew upgrade artagon/aitools/aitools-skills`
    MARKDOWN
  end

  def caveats
    <<~EOS
      Homebrew manages upgrades; do not run `aitools-skills update`,
      `self-update`, or `upgrade` (blocked with exit code 2). Use:
        brew upgrade artagon/aitools/aitools-skills

      Inspect installed `artagon/aitools` skill formulae and detected agent CLIs:
        aitools-skills list
        brew aitools-skills list

      Preview and register tap skills explicitly (the offline symlink backend
      works with zero extra dependencies; install `brew install apm` optionally
      for OpenAPM lockfiles and `apm audit --ci`):
        aitools-skills diff --all-detected
        aitools-skills sync --all-detected
        aitools-skills sync --backend symlink --target claude

      Read the bundled agent guide offline at:
        #{opt_share}/doc/aitools-skills/AGENTS.md

      This formula does not modify any agent configuration, skill, hook, or
      user dotfile during install.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_DATA_HOME"] = (testpath/".local/share").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    brew_root = testpath/"brew"
    ENV["HOMEBREW_PREFIX"] = brew_root.to_s

    assert_match "aitools-skills #{version}", shell_output("#{bin}/aitools-skills --version")
    assert_match "aitools-skills #{version}", shell_output("#{bin}/brew-aitools-skills --version")

    %w[update self-update upgrade].each do |subcmd|
      assert_match "brew upgrade artagon/aitools/aitools-skills",
                   shell_output("#{bin}/aitools-skills #{subcmd} 2>&1", 2)
    end

    assert_path_exists man1/"aitools-skills.1"
    assert_path_exists bash_completion/"aitools-skills"
    assert_path_exists zsh_completion/"_aitools-skills"
    assert_path_exists fish_completion/"aitools-skills.fish"
    assert_path_exists doc/"AGENTS.md"

    cellar_demo = brew_root/"Cellar/demo/1.0.0"
    demo_apm = cellar_demo/"share/demo/apm/demo"
    (demo_apm/"skills/demo-skill").mkpath
    (cellar_demo/"INSTALL_RECEIPT.json").write(
      '{"source":{"tap":"artagon/aitools","versions":{"stable":"1.0.0"}}}',
    )
    (demo_apm/"apm.yml").write <<~YAML
      name: demo
      version: "1.0.0"
      description: "Demo tap skill package"
      dependencies:
        apm: []
        mcp: []
        lsp: []
      includes:
        - skills
    YAML
    (demo_apm/"skills/demo-skill/SKILL.md").write <<~MARKDOWN
      ---
      name: demo-skill
      description: Demo skill for isolated Homebrew testing
      ---

      # Demo Skill
    MARKDOWN
    (brew_root/"opt").mkpath
    (brew_root/"opt/demo").make_symlink("../Cellar/demo/1.0.0")

    listed = JSON.parse(shell_output("#{bin}/aitools-skills list --brew-prefix #{brew_root} --json"))
    assert_equal 1, listed["schema_version"]
    assert listed["ok"]
    assert_equal 1, listed.dig("data", "totals", "formulae")
    assert_equal "demo", listed.dig("data", "formulae", 0, "name")
    assert_equal "native-apm", listed.dig("data", "formulae", 0, "package_format")
    assert_equal "demo-skill", listed.dig("data", "formulae", 0, "skills", 0, "name")

    diffed = JSON.parse(
      shell_output(
        "#{bin}/aitools-skills diff --backend symlink --target claude --brew-prefix #{brew_root} --json",
      ),
    )
    assert diffed["ok"]
    assert_equal "diff", diffed["command"]
    refute_path_exists testpath/".claude"

    synced = JSON.parse(
      shell_output(
        "#{bin}/aitools-skills sync --backend symlink --target claude --brew-prefix #{brew_root} --json",
      ),
    )
    assert synced["ok"]
    assert_equal "sync", synced["command"]
    deployed = testpath/".claude/skills/demo-skill"
    assert_predicate deployed, :symlink?
    assert_path_exists deployed/"SKILL.md"
    assert_includes deployed.readlink.to_s, "/opt/demo/share/demo/apm/demo/skills/demo-skill"

    status = JSON.parse(
      shell_output(
        "#{bin}/aitools-skills status --backend symlink --target claude --brew-prefix #{brew_root} --json",
      ),
    )
    assert status["ok"]
    assert_equal 1, status.dig("data", "summary", "in_sync")
    assert_equal 0, status.dig("data", "summary", "errors")

    doctor = JSON.parse(
      shell_output(
        "#{bin}/aitools-skills doctor --backend symlink --brew-prefix #{brew_root} --json",
      ),
    )
    assert doctor["ok"]
    assert_equal 1, doctor.dig("data", "brew", "formulae")
    assert_equal 0, doctor.dig("data", "summary", "errors")

    %w[.codex .gemini .agents .apm].each do |dotfile|
      refute_path_exists testpath/dotfile
    end
  end
end
