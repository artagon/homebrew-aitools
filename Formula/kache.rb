class Kache < Formula
  desc "Zero-copy, content-addressed build cache for Rust, C/C++, and CUDA"
  homepage "https://github.com/kunobi-ninja/kache"
  url "https://github.com/kunobi-ninja/kache/archive/refs/tags/v2.2.0.tar.gz"
  sha256 "d432233f74b09b9be4ca960b203c3351dd3f4d608edcd662687e4cd6b4fa4e11"
  license "Apache-2.0"
  head "https://github.com/kunobi-ninja/kache.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build

  def install
    # Prevent self-wrapping if the host already configures Kache as Cargo's wrapper.
    ENV["RUSTC_WRAPPER"] = ""

    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"kache", "completions")

    shim_dir = libexec/"shims"
    shim_dir.mkpath
    %w[cc c++ gcc g++ clang clang++ cargo rustdoc].each do |shim|
      shim_dir.install_symlink bin/"kache" => shim
    end
    (shim_dir/".kache-shims").write <<~EOS
      kache toolchain shims. kache skips this directory when it looks for the real toolchain, so keep only shims here.
    EOS

    (pkgshare/"schemas").install "docs/commands/cli.schema.json", "docs/commands/report.schema.json"
    (pkgshare/"examples/local-only/config.toml").write <<~TOML
      # Strict local-only Kache configuration (ignores all remote S3/GCS/OCI and planner settings).
      # Copy to ~/.config/kache/config.toml or .kache.toml in a repository root.
      [cache]
      local_only = true
      record_sessions = false
    TOML
  end

  def caveats
    <<~EOS
      Upgrade Kache through Homebrew:
        brew upgrade artagon/aitools/kache

      This formula does not modify `~/.cargo/config.toml`, shell startup files,
      or user login services during install.

      To enable Rust caching without editing shell profiles:
        export RUSTC_WRAPPER=#{opt_bin}/kache
      To enable C/C++ compiler shims on PATH:
        export PATH="#{opt_libexec}/shims:$PATH"
      Or preview interactive setup before applying any changes:
        kache init --check

      Out of the box, Kache stores artifacts locally and binds its optional daemon
      to a local Unix domain socket (`daemon.sock`) with no remote cache, planner
      endpoint, or telemetry export configured. A strict local-only configuration
      example and JSON schemas are installed under:
        #{opt_pkgshare}/examples/local-only/config.toml
        #{opt_pkgshare}/schemas
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_CACHE_HOME"] = (testpath/".cache").to_s
    ENV["KACHE_CONFIG"] = (testpath/".config/kache/config.toml").to_s
    ENV["KACHE_CACHE_DIR"] = (testpath/"cache").to_s
    ENV["KACHE_RUNTIME_DIR"] = (testpath/"run").to_s

    assert_match "kache #{version}", shell_output("#{bin}/kache --version")
    assert_path_exists bin/"kache-engine"
    assert_path_exists bin/"kache-clang-cl"
    assert_path_exists bin/"kache-cl"
    assert_path_exists bash_completion/"kache"
    assert_path_exists zsh_completion/"_kache"
    assert_path_exists fish_completion/"kache.fish"
    assert_path_exists libexec/"shims/.kache-shims"
    assert_path_exists pkgshare/"schemas/cli.schema.json"
    assert_path_exists pkgshare/"schemas/report.schema.json"
    assert_path_exists pkgshare/"examples/local-only/config.toml"

    # Unknown self-update commands fail closed (exit 2), and planner login refuses when unconfigured.
    shell_output("#{bin}/kache update 2>&1", 2)
    assert_match "no planner is configured", shell_output("#{bin}/kache login 2>&1", 1)

    system bin/"kache", "config", "set", "--file", ENV["KACHE_CONFIG"], "cache.local_only", "true"
    system bin/"kache", "config", "set", "--file", ENV["KACHE_CONFIG"], "cache.daemon_publish", "false"
    assert_equal "true", shell_output("#{bin}/kache config get --file #{ENV["KACHE_CONFIG"]} cache.local_only").strip

    # `init --check` previews changes without mutating `~/.cargo/config.toml`.
    init_preview = shell_output("#{bin}/kache init --check --json")
    assert_match '"preview": true', init_preview
    refute_path_exists testpath/".cargo/config.toml"

    (testpath/"hello.c").write("int add(int a, int b) { return a + b; }\n")
    begin
      compiler = File.basename(ENV.cc)
      system bin/"kache", compiler, "-c", testpath/"hello.c", "-o", testpath/"hello1.o"
      system bin/"kache", compiler, "-c", testpath/"hello.c", "-o", testpath/"hello2.o"
      assert_equal (testpath/"hello1.o").binread, (testpath/"hello2.o").binread

      shim_root = if (libexec/"shims"/compiler).exist?
        libexec/"shims"
      else
        system bin/"kache", "init", "--shims", testpath/"shims"
        testpath/"shims"
      end
      with_env(PATH: "#{shim_root}:#{ENV.fetch("PATH")}") do
        system compiler, "-c", testpath/"hello.c", "-o", testpath/"hello3.o"
      end
      assert_equal (testpath/"hello1.o").binread, (testpath/"hello3.o").binread

      listing = JSON.parse(shell_output("#{bin}/kache list --no-pager --json"))
      assert listing["success"]
      assert_equal 1, listing.fetch("entries").length
      assert_equal "hello.c", listing.fetch("entries").first["crate_name"]
    ensure
      system bin/"kache", "daemon", "stop" if (testpath/"run/daemon.sock").exist?
    end

    status = JSON.parse(shell_output("#{bin}/kache daemon status --json"))
    refute status["daemon_running"]
  end
end
