class MinijinjaCli < Formula
  desc "Render Jinja2 templates directly from the command-line to stdout"
  homepage "https://github.com/mitsuhiko/minijinja"
  url "https://github.com/mitsuhiko/minijinja/archive/refs/tags/3.1.0.tar.gz"
  sha256 "6eddec4714167d07dd29a68c7d1489777e81f6cbc7f164710607b1e9a87837bc"
  license "Apache-2.0"
  head "https://github.com/mitsuhiko/minijinja.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/minijinja-cli-3.1.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "25d5ca681609bebe0b8679a47ecb8343933a79abcb17586019a96fb8a54374c2"
    sha256 cellar: :any,                 arm64_linux:  "9ee251d40835eae9621139f733fda9110fb9733d06401083a4a9b92333616a59"
    sha256 cellar: :any,                 x86_64_linux: "edffdeeae1dd241847b889c56e5d29bab973fda97d5ad86fd1694d6b737ebe0d"
  end

  depends_on "rust" => :build

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    assets = buildpath/"assets"
    assets.mkpath
    ENV["ASSET_OUT_DIR"] = assets.to_s

    system "cargo", "install", *std_cargo_args(path: "minijinja-cli")
    man1.install assets/"man/minijinja-cli.1"
    generate_completions_from_executable(
      bin/"minijinja-cli",
      "--generate-completion",
      shells: [:bash, :zsh, :fish, :pwsh],
    )

    (pkgshare/"skills/minijinja-cli/SKILL.md").write <<~EOS
      ---
      name: minijinja-cli
      description: Render Jinja2 templates and evaluate expressions from the command line with minijinja-cli 3.1.x. Use when rendering templates from JSON, YAML, TOML, INI, CBOR, or query-string data in shell or CI pipelines. Do not use for Rust crate or Python library integration.
      ---

      # Rendering Templates with minijinja-cli (3.1.0)

      ## Core Invocations

      1. Render a template file with merged data files (top-level keys merged left-to-right):
         `minijinja-cli template.j2 defaults.yaml overrides.json -o rendered.txt`
      2. Render an inline `-t` template with data files (pass `""` for `[TEMPLATE_FILE]`):
         `minijinja-cli -t '{{ app.name }}:{{ port }}' "" config.toml -D port:=8080`
      3. Read data from stdin by specifying `-f <auto|cbor|ini|json|querystring|toml|yaml>`:
         `minijinja-cli template.j2 - -f json < payload.json`
      4. Scope context to a nested map before rendering:
         `minijinja-cli service.j2 cluster.yaml --select services.api`
      5. Evaluate expressions without a template (`print`, `json`, `json-pretty`, or `status`; pass `-` before data files):
         `minijinja-cli --expr 'items | selectattr("enabled") | map(attribute="id")' --expr-out json - data.yaml`

      ## Key Flags & Defines

      - `-D key=value` binds a string; `-D key:=expr` parses JSON/YAML (`42`, `true`, `[1,2]`); `-D flag` binds `true`.
      - `--strict` errors on undefined variables; `-n` / `--no-newline` strips the trailing newline.
      - `--trim-blocks` and `--lstrip-blocks` control block whitespace; `--py-compat` enables Python-like methods.
      - `-a <auto|html|json|none>` sets autoescaping; `--env` exposes process environment variables as `ENV`.
      - `--dump <tokens|ast|instructions>` inspects compilation; `--repl` starts an interactive session.

      ## Sandboxing & 3.1.0 Gotchas

      - Restrict untrusted templates with `--no-include` (or `--safe-path <DIR>`) and `--fuel <N>` (for example `50000`).
      - `--fuel 0` is ignored (`fuel > 0` check) and will not clear a non-zero `MINIJINJA_FUEL` or `~/.minijinja.toml` limit.
      - The safe-path env var is `MINIJINJA_SAFE_PATHS` (plural, `:`-separated), despite `MINIJINJA_SAFE_PATH` in `--long-help`.
      - `MINIJINJA_SAFE_PATHS` does not canonicalize symlinks (unlike `--safe-path`); on macOS pass `/private/tmp/...` rather than `/tmp/...`.
      - Custom line comments use `-s line-comment-prefix=##` (and default `comment-end=#}`), despite `line-statement-comment` in `--help`.
      - `minijinja-contrib` `truncate` and `wordwrap` require keyword arguments: `|truncate(length=80)` and `|wordwrap(width=79)`.
    EOS
  end

  def caveats
    <<~EOS
      Homebrew core also provides a `minijinja-cli` formula. Use the tap-qualified
      name to install or upgrade this tap's build:
        brew install artagon/aitools/minijinja-cli
        brew upgrade artagon/aitools/minijinja-cli

      A companion agent skill is staged passively under:
        #{opt_pkgshare}/skills
      Copy or symlink `#{opt_pkgshare}/skills/minijinja-cli` into your agent's
      skill directory to enable it.

      Installing or upgrading this formula never modifies any agent or user
      configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s

    assert_match "minijinja-cli #{version}", shell_output("#{bin}/minijinja-cli --version")

    (testpath/"base.json").write('{"project":{"name":"aitools"},"count":1}')
    (testpath/"override.toml").write("owner = \"artagon\"\n")
    (testpath/"hello.j2").write("{{ project.name }}/{{ owner }}/{{ label }}/{{ n + 1 }}")

    rendered = shell_output(
      "#{bin}/minijinja-cli hello.j2 base.json override.toml -D label=cli -D n:=2",
    )
    assert_equal "aitools/artagon/cli/3\n", rendered

    selected = shell_output(
      "#{bin}/minijinja-cli -t '{{ name }}' '' base.json --select project",
    )
    assert_equal "aitools\n", selected

    expr_json = JSON.parse(
      shell_output("#{bin}/minijinja-cli --expr 'project.name | upper' --expr-out json - base.json"),
    )
    assert_equal "AITOOLS", expr_json

    shell_output("#{bin}/minijinja-cli --strict -t '{{ missing }}' 2>&1", 1)

    (testpath/"part.j2").write("secret")
    (testpath/"main.j2").write('{% include "part.j2" %}')
    shell_output("#{bin}/minijinja-cli --no-include main.j2 2>&1", 1)

    assert_path_exists man1/"minijinja-cli.1"
    assert_path_exists pkgshare/"skills/minijinja-cli/SKILL.md"
    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
