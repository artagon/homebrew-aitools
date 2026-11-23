class PythonMinijinja < Formula
  desc "Python bindings for the MiniJinja Rust template engine"
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
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/python-minijinja-3.1.0"
    sha256 cellar: :any, arm64_tahoe:  "38acbfd0a2b8fd60119b57e2c3ee9b08803e7bab587fb5cdc0439cd101a69474"
    sha256 cellar: :any, arm64_linux:  "5732be54b84aa54431e6b11611508293abf7ddc3fd679b5ce990a5ae9013b9b6"
    sha256 cellar: :any, x86_64_linux: "96cee13d5e459f058c6258658ccfaed1d277c4cd2d80c6e0e63322acfed6b742"
  end

  depends_on "maturin" => :build
  depends_on "python@3.13" => [:build, :test]
  depends_on "python@3.14" => [:build, :test]
  depends_on "python@3.15" => [:build, :test]
  depends_on "rust" => :build

  deny_network_access!

  def fetch
    system "cargo", "fetch", "--locked"
  end

  def pythons
    deps.select { |d| d.name.match? Version.formula_optionally_versioned_regex(:python) }
        .map { |d| formula_opt_libexec(d.name)/"bin/python" }
  end

  def install
    ENV["MATURIN_PEP517_ARGS"] = "--locked --offline"
    pythons.each do |python3|
      system python3, "-m", "pip", "install", *std_pip_args, "./minijinja-py"
    end

    (pkgshare/"skills/minijinja-python/SKILL.md").write <<~EOS
      ---
      name: minijinja-python
      description: Author, render, and sandbox Jinja2 templates in Python 3 using minijinja 3.1.x or Jinja2 3.1.x. Use when embedding MiniJinja in Python, migrating templates between Jinja2 and MiniJinja, or hardening untrusted template rendering. Do not use for Rust crate or standalone CLI workflows.
      ---

      # Python MiniJinja (3.1.0) & Jinja2 Portability

      ## Core Python API (`minijinja`)

      - Build a reusable `Environment(loader=load_from_path(tpl_dir), fuel=50_000, undefined_behavior="strict")`.
      - Render named templates via `env.render_template("page.html", **ctx)` or strings via `env.render_str(src, "page.html", **ctx)`.
      - Evaluate standalone expressions with `env.eval_expr("items | map('upper') | list", items=xs)`.
      - Decorate custom filters or functions with `@pass_state` to inspect `state.name`, `state.auto_escape`, or `state.lookup(...)`.
      - Mark trusted HTML fragments with `Markup` (or `safe(...)`); `minijinja` honors `__html__()` without requiring `markupsafe`.

      ## Jinja2 <-> MiniJinja Portability Rules

      - `minijinja.Environment()` enables `pycompat=True` by default (read-only `str`/`dict`/`list.count` methods), never mutating `.append()` or `.update()`; use `namespace()` for loop state.
      - Pass keyword arguments to `truncate` and `wordwrap`: `{{ s|truncate(length=80) }}` and `{{ s|wordwrap(width=79) }}` (positional args fail in `3.1.0`, `#1033`).
      - `render_str(src)` defaults template name to `"<string>"` (no autoescape); pass an `.html`/`.xml`/`.json` name (`render_str(src, "x.html", ...)`) or `auto_escape_callback`.
      - Format strings with `"%s"|format(x)` or `~` concatenation (`%` is modulo only); pass state to macros instead of `{% include ... without context %}`.

      ## Defensive Sandboxing

      - Never compile untrusted user strings as template source (`render_str(user_input)`); pass untrusted values as context variables with HTML/JSON autoescaping, and never rely on `|striptags` for sanitization (`#1035`).
      - For user-authored templates in `minijinja`, set `Environment(fuel=50_000, loader=load_from_path(jail_dir))` (`load_from_path` rejects `..` and `\\` paths) and pass plain `dict`/`list`/primitive data only (public methods on passed Python instances remain callable).
      - In Pallets `jinja2`, use `ImmutableSandboxedEnvironment(autoescape=True)` and enforce external wall-clock/memory limits.
    EOS
  end

  def caveats
    <<~EOS
      Install or upgrade this formula with:
        brew install artagon/aitools/python-minijinja
        brew upgrade artagon/aitools/python-minijinja

      `minijinja` is installed into Homebrew's versioned Python `site-packages`
      directories for direct `import minijinja` usage.

      A companion agent skill is staged passively under:
        #{opt_pkgshare}/skills
      Copy or symlink `#{opt_pkgshare}/skills/minijinja-python` into your agent's
      skill directory to enable it.

      Installing or upgrading this formula never modifies any agent or user
      configuration file.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/"config").to_s

    (testpath/"templates").mkpath
    (testpath/"templates/ok.html").write("Hello {{ user }}")
    (testpath/"secret.html").write("top-secret")

    (testpath/"test.py").write <<~PYTHON
      from minijinja import (
          Environment,
          Markup,
          TemplateError,
          eval_expr,
          load_from_path,
          pass_state,
          render_str,
      )

      html = render_str(
          "<b>{{ untrusted }}</b> {{ trusted }}",
          "snippet.html",
          untrusted="<script>",
          trusted=Markup("<i>ok</i>"),
      )
      assert html == "<b>&lt;script&gt;</b> <i>ok</i>", html

      assert eval_expr("nums | map('abs') | sum", nums=[-2, 3, -5]) == 10

      @pass_state
      def prefix_template(state, value):
          return f"{state.name}:{value}"

      env = Environment(
          loader=load_from_path("templates"),
          filters={"prefix_template": prefix_template},
      )
      assert env.render_template("ok.html", user="<Ada>") == "Hello &lt;Ada&gt;"
      assert env.render_str("{{ 'hi' | prefix_template }}", "view.txt") == "view.txt:hi"
      assert env.render_str(
          "{% for k, v in data.items() %}{{ k }}={{ v.strip() }}{% endfor %}",
          data={"mode": " fast "},
      ) == "mode=fast"

      try:
          env.render_template("../secret.html")
      except TemplateError:
          pass
      else:
          raise AssertionError("expected traversal rejection")

      limited = Environment(fuel=5)
      try:
          limited.render_str("{% for i in range(100) %}{{ i }}{% endfor %}")
      except TemplateError as exc:
          assert "fuel" in str(exc).lower(), exc
      else:
          raise AssertionError("expected fuel exhaustion")
    PYTHON

    pythons.each do |python3|
      system python3, "test.py"
    end

    assert_path_exists pkgshare/"skills/minijinja-python/SKILL.md"
    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
