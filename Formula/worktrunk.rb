class Worktrunk < Formula
  desc "CLI for Git worktree management, designed for parallel AI agent workflows"
  homepage "https://worktrunk.dev"
  url "https://github.com/max-sixty/worktrunk/archive/refs/tags/v0.83.0.tar.gz"
  sha256 "66d22decd0484defc701c4df2ac141f8b000fb17bbc9e8b2d9f12d00f456ec20"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/max-sixty/worktrunk.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/worktrunk-0.83.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "fa7db20a60cc6410891e7414950697f2b26822e20166df0525b8898ccfa42a42"
    sha256 cellar: :any,                 arm64_linux:  "4e89ce96479f239687950632f04f5b0620013fbc5dd31901994367f9e92ca3d3"
    sha256 cellar: :any,                 x86_64_linux: "29b5bd255a5ca0b502d51265e36fef41528e7fde2235db3a023ff05ee4d5f07b"
  end

  depends_on "rust" => :build

  conflicts_with "wiredtiger", because: "both install `wt` binaries"

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    ENV["VERGEN_GIT_DESCRIBE"] = "v#{version}"

    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"wt", "config", "shell", "completions")

    (pkgshare/"skills").install "skills/worktrunk", "skills/wt-switch-create"
    (pkgshare/"plugins").install "plugins/worktrunk", "plugins/worktrunk-markers"
    (pkgshare/"hooks").install "hooks/hooks.json"
    pkgshare.install "gemini-extension.json"
    (pkgshare/"examples").install "dev/config.example.toml",
                                  "dev/wt.example.toml",
                                  "dev/opencode-plugin.ts",
                                  "dev/pi-extension.ts",
                                  "dev/omp-hook.ts"
  end

  def caveats
    <<~EOS
      Because `homebrew/core` also provides a `worktrunk` formula, always qualify
      this tap when installing or upgrading (do not run upstream
      `worktrunk-installer.sh`):
        brew install artagon/aitools/worktrunk
        brew upgrade artagon/aitools/worktrunk

      Installing or upgrading this formula never modifies shell startup profiles
      or coding-agent configurations (`~/.claude*`, `~/.codex*`, `~/.gemini*`,
      `~/.agents`, or `~/.config/*`).

      Shell directory-switching integration is strictly opt-in:
        eval "$(wt config shell init zsh)"   # or bash / fish / nu
        wt config shell install              # interactive profile setup

      Worktrunk runs locally with zero telemetry or startup update checks (only
      opt-in `wt config show --full` checks GitHub for newer releases). LLM
      commit message generation (`[commit.generation]`) stays off unless
      configured in `~/.config/worktrunk/config.toml` (an interactive TTY may
      prompt once on first commit when `claude`, `codex`, or `opencode` is on
      `PATH`).

      Upstream agent skills, plugins, activity-marker hooks, and config examples
      are staged passively under:
        #{opt_pkgshare}/skills
        #{opt_pkgshare}/plugins
        #{opt_pkgshare}/hooks/hooks.json
        #{opt_pkgshare}/gemini-extension.json
        #{opt_pkgshare}/examples
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s
    ENV["GIT_CONFIG_GLOBAL"] = File::NULL
    ENV["GIT_CONFIG_NOSYSTEM"] = "1"
    ENV["GIT_AUTHOR_NAME"] = "Brew Test"
    ENV["GIT_AUTHOR_EMAIL"] = "brew@example.com"
    ENV["GIT_COMMITTER_NAME"] = "Brew Test"
    ENV["GIT_COMMITTER_EMAIL"] = "brew@example.com"

    assert_match "wt v#{version}", shell_output("#{bin}/wt --version")
    assert_path_exists bash_completion/"wt"
    assert_path_exists zsh_completion/"_wt"
    assert_path_exists fish_completion/"wt.fish"
    assert_path_exists pkgshare/"skills/worktrunk/SKILL.md"
    assert_path_exists pkgshare/"skills/wt-switch-create/SKILL.md"
    assert_path_exists pkgshare/"plugins/worktrunk/.claude-plugin/plugin.json"
    assert_path_exists pkgshare/"plugins/worktrunk/.codex-plugin/plugin.json"
    assert_path_exists pkgshare/"plugins/worktrunk/hooks/hooks.json"
    assert_predicate pkgshare/"plugins/worktrunk/hooks/wt.sh", :executable?
    assert_path_exists pkgshare/"plugins/worktrunk-markers/.codex-plugin/plugin.json"
    assert_predicate pkgshare/"plugins/worktrunk-markers/hooks/wt.sh", :executable?
    assert_path_exists pkgshare/"hooks/hooks.json"
    assert_path_exists pkgshare/"gemini-extension.json"
    assert_path_exists pkgshare/"examples/config.example.toml"
    assert_path_exists pkgshare/"examples/wt.example.toml"
    assert_path_exists pkgshare/"examples/opencode-plugin.ts"
    assert_path_exists pkgshare/"examples/pi-extension.ts"
    assert_path_exists pkgshare/"examples/omp-hook.ts"

    assert_match "WORKTRUNK_DIRECTIVE_CD_FILE", shell_output("#{bin}/wt config shell init zsh")
    assert_match "WORKTRUNK_DIRECTIVE_CD_FILE", shell_output("#{bin}/wt config shell init bash")

    repo = testpath/"repo"
    system "git", "init", "-b", "main", repo
    cd repo do
      (repo/".gitignore").write(".env.local\n.secret.skip\n")
      (repo/".worktreeinclude").write(".env.local\n")
      (repo/"README.md").write("# Test Repo\n")
      system "git", "add", ".gitignore", ".worktreeinclude", "README.md"
      system "git", "commit", "-m", "Initial commit"

      (repo/".env.local").write("APP_PORT=5173\n")
      (repo/".secret.skip").write("DO_NOT_COPY=1\n")

      port = shell_output("#{bin}/wt step eval '{{ branch | hash_port }}'").strip.to_i
      assert_includes 10_000..19_999, port

      system bin/"wt", "switch", "--create", "feature", "--no-cd", "--no-hooks"
      feature_wt = testpath/"repo.feature"
      assert_path_exists feature_wt/"README.md"

      listing = JSON.parse(shell_output("#{bin}/wt list --format json"))
      assert_kind_of Hash, listing
      assert_equal 2, listing["schema"]
      assert_kind_of Array, listing["items"]
      assert listing["items"].any? { |entry| entry["branch"] == "feature" }

      system bin/"wt", "step", "copy-ignored", "--to", "feature", "--require-include"
      assert_equal "APP_PORT=5173\n", (feature_wt/".env.local").read
      refute_path_exists feature_wt/".secret.skip"

      system bin/"wt", "remove", "--foreground", "--no-hooks", "feature"
      refute_path_exists feature_wt
    end

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".claude.json"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
    refute_path_exists testpath/".zshrc"
    refute_path_exists testpath/".bashrc"
  end
end
