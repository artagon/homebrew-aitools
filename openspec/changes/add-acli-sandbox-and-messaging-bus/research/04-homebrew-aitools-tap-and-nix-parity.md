# Iteration 3B Research: `artagon/aitools` Homebrew Tap Packaging, Bottle Signing, & Zero-Builder Nix Parity

**Date:** 2026-11-22  
**Audited Tap & Runtime Surface (`verified`):** `<tap-root>/AGENTS.md`, `<tap-root>/docs/agent-context.md`, `<tap-root>/Formula/{agent-mail,nats,br,bd,bv,herdr,phoenix-cli,arize-phoenix,langfuse-cli,openlit,mlflow,agenthooks,entire-graph,waza,skillopt}.rb`, `<tap-root>/rules/ruby/formula-conflicts-same-name.yml`, `<tap-root>/scripts/{install-agent-skills,autobump,update-tap-docs}.sh`, `<tap-root>/scripts/ci/plan-ci.sh`, `<tap-root>/.github/workflows/{tests,publish,sign-bottles}.yml`, Homebrew `7.0.5+` (`formula.rb` commit `702cc64b18` introducing `std_cargo_fetch_args`, `dependency_collector.rb`, `keg_relocate.rb`) + `ruby-macho 7.0.0` (`code_signing.rb`), `homebrew-core` (`libkrun 1.19.8`, `bubblewrap`, `slirp4netns`, `krunkit 1.3.2`, `container 1.7.1`, `vfkit 0.6.4`), `nats-server v2.15.3` (`server/opts.go:6142-6177`), `bd v1.3.4` (`gastownhall/beads`), `br v0.7.6` (`beads_rust`), `bv v0.27.0` (`beads_viewer`), and `nixpkgs-unstable` (`2786a2a7`).

> [!IMPORTANT]
> **Iteration 3B Verdict:** Deliver the host launcher, supervisor, 3-plane messaging stack, and pure-Rust production telemetry stack through offline-building (**`Homebrew >= 7.0.5`** source-build floor; bottle-pour compatibility published separately), hardened `artagon/aitools` formulae (`Formula/agent-mail.rb` `0.3.41` `revision 1`, `Formula/nats.rb` `0.5.2` `revision 1`, Stage-1 self-contained `Formula/nats-server.rb` `2.15.3` with field-independent `libexec/bin/nats-bind-preflight` and **zero Stage-2 `acli` dependency**, Dual-Engine Beads `Formula/br.rb` `0.7.6` `revision 1` [blocking `br upgrade` with `exit 2`] + `Formula/bd.rb` `1.3.4` `revision 2` [`DOLT_METRICS_DISABLED=1` + `BD_DISABLE_EVENT_FLUSH=1`], and pure-Rust `Formula/acli.rb` [direct Mach-O/ELF `bin/acli` symlink for `< 3 ms` `acli hook emit` + `/bin/bash` `3.2` `bin/aclid` `ACLI_SHIM_PATH` wrapper, `0` Python/DuckDB runtime bloat, pairing with existing tap `Formula/phoenix-cli.rb` `1.22.1`, `Formula/arize-phoenix.rb` `21.1.0`, `Formula/langfuse-cli.rb` `1.3.1`, `Formula/openlit.rb` `2.1.1`, `Formula/mlflow.rb` `3.18.0`, and optional `Formula/artagon-harness-eval.rb`]) plus Stage 0 tap workflow prerequisites and a per-artifact/platform lockfile (`versions/aitools-lock.json`) verified on cold isolated stores under stock **`--option builders ''`**. Signing `libexec/bin/acli-shim` inside `def install` via `/usr/bin/codesign --force --sign - --id com.artagon.acli.shim --entitlements acli-shim.entitlements` (embedding **only** `com.apple.security.hypervisor = true` alongside `__TEXT,__info_plist` and `__TEXT,__restrict`, with **zero** `cs.disable-library-validation`) clears `CS_LINKER_SIGNED` (`0x20000`), guaranteeing that `--preserve-metadata` and `MachO.codesign!` preserve binary slot `5` (`0xfade7171` XML plist) and Apple Silicon slot `7` (`0xfade7172` DER) decoding to boolean `true` and **exact `CodeDirectory` `Identifier == "com.artagon.acli.shim"`** across distinct-prefix `cellar: :any` pours and `sign-bottles.yml` SLSA v1 / `cosign` v3 outer-tarball signing.

---

## 1. `artagon/homebrew-aitools` Tap Law, `Homebrew >= 7.0.5` Floor, & Stage 0 Prerequisites (`verified`)

| Tap Boundary | Mandatory Invariant (`verified` in `<tap-root>/AGENTS.md` & Homebrew `formula.rb`) | CI / Lint Enforcement |
| --- | --- | --- |
| **1. `/bin/bash` 3.2 Wrappers** | Target stock macOS `/bin/bash` `3.2` with `set -euo pipefail`. Keep arrays nonempty before expansion (`${arr[@]+"${arr[@]}"}`). Terminate wrapper flag scans at `--` using a state machine skipping valued options. Forbid Bash 4+ builtins (`mapfile`, `readarray`, `declare -A`, `local -n`). Format `scripts/**/*.sh` with separate-line `then`/`do` and `${var}` braces. | `bash-no-mapfile-readarray`, `bash-no-bash4-features`, `brew style`, `shell-compat-macos` (`tests.yml`) |
| **2. Loopback, Privacy, & Self-Mutating Binary Updater Block** | Stage bare binaries in `libexec/` (`chmod 0755`). Disable telemetry (`DO_NOT_TRACK=1`, `OTEL_SDK_DISABLED=true`). Bind local servers deterministically to **`127.0.0.1`** by default via field-independent `libexec/bin/nats-bind-preflight` (exiting `78` `E78:ambiguous_nats_bind` on duplicate top-level address or port setters). Block **only self-mutating binary updaters** (`self-update` and `update` on `agent-mail` and `nats`, and `br upgrade` on `Formula/br.rb`) with **`exit 2`**, while **explicitly preserving** non-updater subcommands such as `bd update` (ordinary issue mutations) and `bd upgrade` (informational post-upgrade guidance) on `Formula/bd.rb` (`SOL-R15-01`). | Formula `test do` (`shell_output(..., 2)`), standalone Stage-1 listener checks |
| **3. `Homebrew >= 7.0.5` Offline Source-Build Floor** | Source builds of `acli`, `nats`, and `nats-server` require **`Homebrew >= 7.0.5`** (the exact release containing upstream commit `702cc64b18` introducing `std_cargo_fetch_args`, alongside `def fetch` and automatic `std_cargo_args` `--offline` injection; bottle-pour support for older Homebrew clients is published separately). Test source builds in CI on `Homebrew >= 7.0.5` with **cold Cargo and Go caches** under `deny_network_access! [:build, :postinstall]`. | Cold-cache `brew install --build-from-source`, `brew test-bot` |
| **4. Zero Live Dotfile Mutation & Multi-Tool `pkgshare`** | `brew install`, `upgrade`, `uninstall`, and `test do` (`ENV["HOME"] = testpath.to_s`, `ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s`) must **never** touch live `$HOME/.*` dotfiles (optional background supervision is installed explicitly by the user via `acli daemon install`). Stage skills under `pkgshare/"skills/<name>/SKILL.md"` consumed by `scripts/install-agent-skills.sh --tool ripwire\|agent-mail\|acli\|all` across all 9 CLIs. | `tests/integration_agent_install.bats` |
| **5. Literal URLs, `livecheck`, & Guest `resource` Co-Bumps** | Direct class-body `livecheck do ... end`; literal-versioned `url "..."` + `sha256 "<64-lowercase-hex>"`. `scripts/autobump.sh` and `scripts/check-aitools-lock.sh` co-update and verify all platform blocks **and** `Formula/acli.rb`'s `resource "guest-{aarch64,x86_64}-linux-musl"` blocks plus `versions/aitools-lock.json`. | `formula-livecheck`, `formula-no-interpolated-url`, `formula-source-sha256`, `check-aitools-lock.sh` |
| **6. Qualification & `conflicts_with` Rule** | Qualify all install/upgrade examples as `artagon/aitools/<name>`. Never declare `conflicts_with` on same-named formulae across taps (`tgrep`, `nats`, `herdr`, `nats-server`). | `<tap-root>/rules/ruby/formula-conflicts-same-name.yml` |
| **7. Stage 0 Prerequisites, 3-Platform Bottles, & SLSA v1** | Land `scripts/install-agent-skills.sh`, `scripts/autobump.sh`, `scripts/ci/plan-ci.sh` (`versions/*` trigger), `scripts/check-aitools-lock.sh`, and `rules/ruby/formula-conflicts-same-name.yml` in a dedicated **Stage 0 PR** before Stage 1 bottle PRs (`publish.yml` `check_protected_paths` rule). | `publish.yml`, `sign-bottles.yml`, `./scripts/update-tap-docs.sh --check`, `actionlint`, `zizmor --persona=auditor` |

---

## 2. Hardened Formula Upgrades & Additions (`verified` Upstream Digests)

### 2.1 `Formula/agent-mail.rb` (`0.3.41` `revision 1`, Dual-Entrypoint `self-update|update` Guard)

- **Verified `v0.3.41` (`2026-11-21`, already landed un-wrapped on `main`) Release URLs & 64-Hex SHA-256 Digests (`verified`):**
  - `macos/arm`: `https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.41/mcp-agent-mail-aarch64-apple-darwin.tar.xz` (`sha256 "1fa85ffa1578b5979d250f2ef3ae4b2fc6ae730cd50c84815755edd87b81ad4d"`)
  - `macos/intel`: `https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.41/mcp-agent-mail-x86_64-apple-darwin.tar.xz` (`sha256 "0743ca92e0a1ee938bed7d750fc7516ab4323a51ee0fb511881dcce01fc93c4a"`)
  - `linux/arm`: `https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.41/mcp-agent-mail-aarch64-unknown-linux-gnu.tar.xz` (`sha256 "5e0106db798433e153eb28e4abca16dcebcdb998e6069ba87b6fa2aa5d7c9d93"`)
  - `linux/intel`: `https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v0.3.41/mcp-agent-mail-x86_64-unknown-linux-musl.tar.xz` (`sha256 "30b3866304b26d14428ce0f85d34e422aca699519f1196ec2f58fbdcdb9e7ccd"`)
- **Dual-Wrapper Contract (`revision 1`):** Bump `Formula/agent-mail.rb` (`0.3.41`) to `revision 1`, preserve `license :cannot_represent` + `prefix.install "LICENSE"`, stage `libexec.install "mcp-agent-mail", "am"` (`chmod 0755`), wrap **both** `bin/"am"` and `bin/"mcp-agent-mail"` blocking **`self-update` and `update` with `exit 2`** (including `AM_INTERFACE_MODE=cli mcp-agent-mail self-update`) while preserving **`am upgrade`** and server modes (`HTTP_HOST=127.0.0.1`, `CONVERT_IMAGES=false`, `DO_NOT_TRACK=1`), and stage `pkgshare/"skills/agent-mail/SKILL.md"`.

### 2.2 `Formula/nats.rb` (`0.5.2` `revision 1`) & Field-Independent `Formula/nats-server.rb` (`2.15.3`)

1. **`Formula/nats.rb` (`0.5.2` `revision 1`, `Homebrew >= 7.0.5` Source Floor — `SOL-R2-06`, `SOL-R4-02`):**
   - `url "https://github.com/nats-io/natscli/archive/refs/tags/v0.5.2.tar.gz"` · `sha256 "6a735b879a19a7abaa4b45e512f23ddb7df6e8f1cd14b32091cd8568e4e94f63"` (`verified`, already on `main` without offline `def fetch` or wrapper).
   - Bump to `revision 1` with `def fetch` (`go mod download`) + `deny_network_access! [:build, :postinstall]` + `libexec/` staging; inject `NATS_URL="nats://127.0.0.1:4222"` **ONLY when all 4 hold**: no `-s`/`--server`/`--context` flags before `--`, `[ -z "${NATS_URL:-}" ]`, `[ -z "${NATS_CONTEXT:-}" ]`, and no non-empty `${XDG_CONFIG_HOME:-$HOME/.config}/nats/context.txt`.
2. **`Formula/nats-server.rb` (`2.15.3`, Planned Stage-1 Field-Independent `libexec/bin/nats-bind-preflight` — `SOL-R6-01,02`):**
   - `url "https://github.com/nats-io/nats-server/archive/refs/tags/v2.15.3.tar.gz"` · `sha256 "034a2a7535d67ae6f28962976a530dad1bd912dd2d9af05a3990f3b7e674008e"` (`verified`).
   - Planned to ship in **Stage 1** (Task 1.4, `not yet executed`) with **zero runtime or build dependency on Stage 2 `acli`** (to be verified standalone in Stage 1 with `acli` absent from `PATH`), using `def fetch` (`go mod download`), `deny_network_access! [:build, :postinstall]`, `allow_network_access! :test`, omitting `service do`, and registering `"nats-server"` in `rules/ruby/formula-conflicts-same-name.yml`.
   - Compiles self-contained Go helper **`libexec/bin/nats-bind-preflight`** against `nats-server v2.15.3`'s already-fetched `github.com/nats-io/nats-server/v2/conf` + `server.ProcessConfigFile` packages:
     1. **Go `flag.FlagSet` Prefix, Blank-Address Rejection, & Option-Segment Grammar (`SOL-R5-02`, `SOL-R6-02`):** Normalizes **both** single-hyphen and double-hyphen prefixes (`-` and `--`) for `a`, `addr`, `net`, `p`, `port`, `c`, and `config` (`server/opts.go:6142-6177`, both split `<flag> <val>` and `<flag>=<val>` forms), honors Go flag value consumption across non-target flags and last-flag-wins repeat order, **rejects an empty or whitespace-only effective CLI bind address (`-a ""`, `--addr=""`, `--net=""`) prior to `exec` with `exit 78` (`E78:ambiguous_nats_bind`)**, stops option scanning at `--`, and inserts any generated `--addr 127.0.0.1` / `-p 4222` inside the parsed option segment before `--` / positional arguments.
     2. **Case-Insensitive Per-Field Ambiguity Check (`SOL-R5-03`):** After `include` expansion, normalizes effective top-level keys case-insensitively and exits **`78` (`E78:ambiguous_nats_bind`)** whenever **multiple top-level directives set the same effective field**: `host` + `net` (duplicate address setters), `listen` + `host`/`net` (duplicate address setters), or `listen` + `port` (duplicate port setters) — preserving the ordinary valid `host` + `port` pair and scoping nested blocks (`leafnodes`, `cluster`, `gateway`, `websocket`, `mqtt`) separately without overriding top-level client defaults.
     3. **Field-Independent Address vs. Port Precedence (`SOL-R5-01`, `SOL-R6-02`):** Resolves client bind `address` and client bind `port` **independently**, each following `explicit non-empty CLI flag > validated single-source non-empty top-level config > safe default (127.0.0.1 for address; 4222 for port)` (treating empty config `host: ""` as hostless so `--addr 127.0.0.1` is still injected):
        - Injects **`--addr 127.0.0.1`** iff NEITHER an explicit non-empty CLI address flag NOR a validated non-empty top-level config address (`host`, `net`, or host-bearing `listen`) is present — **even when an explicit CLI port (`-p 14222`) IS passed** with a hostless config or no config!
        - Injects **`-p 4222`** iff NEITHER an explicit CLI port flag NOR a validated top-level config port (`port` or port-bearing `listen`) is present — **even when an explicit CLI address IS passed**!
        - Suppresses generated `--addr` ONLY when an explicit non-empty CLI address flag or validated non-empty config address sets it (passing `--addr <config_host>` when resolved from config without CLI address); suppresses generated `-p` ONLY when an explicit CLI port flag or validated config port sets it (passing `-p <config_port>` when resolved from port-bearing `listen` without CLI port). Planned Stage-1 `brew test nats-server` verification (Task 1.4, `not yet executed`) will assert that `nats-server -p <free_port> -c hostless.conf` binds strictly `127.0.0.1:<free_port>` (`0` wildcard listeners) and that split/equals blank CLI bind addresses exit `78`.

### 2.3 Dual-Engine Beads Formulae: `Formula/bd.rb` (`1.3.4`, `revision 2`) & `Formula/br.rb` (`0.7.6`, `revision 1`)

- **Verified `bd v1.3.4` (`gastownhall/beads`) & `br v0.7.6` (`beads_rust`) 64-Hex SHA-256 Digests & Per-Arch Linkage (`verified`):**
  - `bd 1.3.4` `macos/arm64` (`beads_1.3.4_darwin_arm64.tar.gz`): `b08a9c15bff80c42235f32946f94a6566a7d90944fe8afe45f3fd2f350596cdb` (Mach-O arm64, `libresolv` + `CoreFoundation` + `Security` + `libSystem` only)
  - `bd 1.3.4` `macos/x86_64` (`beads_1.3.4_darwin_amd64.tar.gz`): `05e713a2da8eeaba40b924184735d9a34d2da8669e4d3ac50cc716605ba10640` (Mach-O x86_64)
  - `bd 1.3.4` `linux/arm64` (`beads_1.3.4_linux_arm64.tar.gz`): `f4ee6eb3ec79bb2d7eb9d717c73efbcb6fa763cc70f726b4d055b72afdd68ad5` (`137.5 MiB` ELF64 `EM_AARCH64`, `PT_INTERP = /lib/ld-linux-aarch64.so.1`, `DT_NEEDED = [libc.so.6, ld-linux-aarch64.so.1]`, `0` `libstdc++`/`libicu`)
  - `bd 1.3.4` `linux/x86_64` (`beads_1.3.4_linux_amd64.tar.gz`): `175c26904bde3ff9168d2282ff6b56f17b17f60c22fa5acb3dacc9fb3465303a` (`147.4 MiB` ELF64 `EM_X86_64`, `PT_INTERP = /lib64/ld-linux-x86-64.so.2`, `DT_NEEDED = [libc.so.6]`, `0` `libstdc++`/`libicu`)
  - `br 0.7.6` `macos/arm64`: `d01a4ef66aa5cd40152fc6481b78def7b6dfefd56da1b26dd1c84b38603de6f6` · `macos/x86_64`: `7732a5bfa954f559bf0822ada071f32416b8a46e32ad33819c07d5942b29c46e` · `linux/arm64` (`musl`): `7b6ea53d1b3b835115074e18bf6794caaf335bbe5b4f45fdb8091a9cf67c633a` · `linux/x86_64` (`musl`): `28b89f8f26540a4c9e6242b3c9fc93bcdd89f4ec0b9c9792895028c53f5bf2bd`
- **`Formula/bd.rb` `revision 2` Unconditional Embedded-Dolt & Flusher Privacy Gate (`SOL-R11-03`, `SOL-R12-01`, `CARBON-R11-05`):** `bd v1.3.4` embeds `github.com/dolthub/driver v2.2.0`, whose gRPC usage emitter checks **`DOLT_METRICS_DISABLED`** independently of `BD_DISABLE_METRICS=1` and `BD_DISABLE_EVENT_FLUSH=1` (`verified` in pinned Go source), while parameter-default fallbacks (`${BD_DISABLE_EVENT_FLUSH:-1}`) would let an inherited `BD_DISABLE_EVENT_FLUSH=0` re-enable the detached flusher (`SOL-R12-01`). Bump `Formula/bd.rb` (`v1.3.4`, `conflicts_with "beads"` — valid per `formula-conflicts-same-name.yml` because `"beads" != "bd"`) to **`revision 2`** with **unconditional forced exports** **`export BD_DISABLE_METRICS=1 BD_DISABLE_EVENT_FLUSH=1 DOLT_METRICS_DISABLED=1 DO_NOT_TRACK=1`** in the `/bin/bash` `3.2` `bin/bd` wrapper, in install-time bare `libexec/"bd"` completion generation, in `caveats`, and in `test do` — where `test do` invokes `BD_DISABLE_EVENT_FLUSH=0 DOLT_METRICS_DISABLED=0 BD_DISABLE_METRICS=0 DO_NOT_TRACK=0 #{bin}/bd ...` and **first verifies that the wrapped child's effective environment sets all four variables (`BD_DISABLE_METRICS`, `BD_DISABLE_EVENT_FLUSH`, `DOLT_METRICS_DISABLED`, `DO_NOT_TRACK`) to `1` BEFORE executing the fixture's first embedded-Dolt database operation**, then runs the isolated temp embedded-Dolt workspace with a due metrics marker asserting zero detached `bd send-metrics` process starts and zero Dolt usage gRPC egress (`SOL-R13-01`; `bd` has no binary `self-update` command, while `bd update` mutates issues and `bd upgrade` manages `.beads/.local_version` release notes).
- **`Formula/br.rb` `revision 1` Self-Update Block (`CARBON-R11-05`):** Live `br 0.7.6` exposes an in-place `br upgrade` binary self-updater (`--force`, `--version <VERSION>`). Bump `Formula/br.rb` (`v0.7.6`) to **`revision 1`**, staging `libexec.install "br"` (`chmod 0755`) with a `/bin/bash` `3.2` `bin/br` wrapper (`set -euo pipefail`, flag scan stopping at `--` skipping valued `--db`/`--actor`/`--format`/`--lock-timeout`) that blocks **`br upgrade` with `exit 2`** pointing to `brew upgrade artagon/aitools/br` (while `aclid` execs `opt_libexec/"br"` directly).

---

## 3. `Formula/acli.rb`: `Homebrew >= 7.0.5` `std_cargo_fetch_args`, Pure-Rust Telemetry, & Exact `CodeDirectory` ID

### 3.1 Reference `Formula/acli.rb` (`SOL-R4-02`, `SOL-R3-03`, `CARBON-R3-01`)

```ruby
class Acli < Formula
  desc "Sandboxed AI coding CLI launcher, multiplexer, and messaging bus"
  homepage "https://github.com/artagon/acli"
  url "https://github.com/artagon/acli/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<64-lowercase-hex>"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  # Source builds require Homebrew >= 7.0.5 (702cc64b18: def fetch + std_cargo_fetch_args + automatic --offline);
  # prebuilt 3-platform bottles pour cleanly without source-build toolchains.
  deny_network_access! [:build, :postinstall]
  allow_network_access! :test

  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "artagon/aitools/agent-mail"
  depends_on "artagon/aitools/bd"
  depends_on "artagon/aitools/br"
  depends_on "artagon/aitools/nats-server"

  on_macos do
    on_arm do
      depends_on "libkrun"
    end
  end

  on_linux do
    depends_on "bubblewrap"
    depends_on "libkrun"
    depends_on "slirp4netns"
  end

  resource "guest-aarch64-linux-musl" do
    url "https://github.com/artagon/acli/releases/download/v0.1.0/acli-guest-aarch64-unknown-linux-musl.tar.xz"
    sha256 "<64-lowercase-hex>"
  end

  resource "guest-x86_64-linux-musl" do
    url "https://github.com/artagon/acli/releases/download/v0.1.0/acli-guest-x86_64-unknown-linux-musl.tar.xz"
    sha256 "<64-lowercase-hex>"
  end

  def fetch
    super
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    if OS.mac?
      pad = "-C link-arg=-Wl,-headerpad_max_install_names"
      ENV["CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS"] = pad
      ENV["CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS"] = pad
    end

    %w[acli aclid acli-shim].each do |crate|
      next if crate == "acli-shim" && OS.mac? && Hardware::CPU.intel?
      system "cargo", "install", *std_cargo_args(path: "crates/#{crate}", root: libexec)
    end

    guest_arch = Hardware::CPU.arm? ? "aarch64" : "x86_64"
    guest_dir = pkgshare/"guest/#{guest_arch}-unknown-linux-musl"
    resource("guest-#{guest_arch}-linux-musl").stage do
      guest_dir.install "acli-guest-supervisor", "acli-guest-proxy", "acli"
      chmod 0755, [guest_dir/"acli-guest-supervisor", guest_dir/"acli-guest-proxy", guest_dir/"acli"]
    end

    if OS.mac? && Hardware::CPU.arm?
      entitlements = buildpath/"crates/acli-shim/acli-shim.entitlements" # ONLY com.apple.security.hypervisor = true
      system "/usr/bin/codesign", "--force", "--sign", "-",
             "--id", "com.artagon.acli.shim",
             "--entitlements", entitlements,
             libexec/"bin/acli-shim"
    end

    # Direct Mach-O/ELF symlink for bin/acli (0 /bin/bash fork so acli hook emit stays < 3 ms;
    # crates/acli blocks self-update|update -> exit 2 natively in Rust).
    bin.install_symlink libexec/"bin/acli"

    shim_line = if (OS.mac? && Hardware::CPU.arm?) || OS.linux?
      "export ACLI_SHIM_PATH=\"#{opt_libexec}/bin/acli-shim\""
    else
      "# acli-shim unsupported on Intel macOS"
    end

    (bin/"aclid").write <<~SH
      #!/bin/bash
      set -euo pipefail
      for arg in "$@"; do
        case "$arg" in
          --) break ;;
          self-update|update)
            echo "aclid: in-place self-update is disabled; run: brew upgrade artagon/aitools/acli" >&2
            exit 2
            ;;
          -*) ;;
          *) break ;;
        esac
      done
      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
      export OTEL_SDK_DISABLED="${OTEL_SDK_DISABLED:-true}"
      #{shim_line}
      exec "#{opt_libexec}/bin/aclid" "$@"
    SH
    chmod 0755, bin/"aclid"

    (pkgshare/"skills").install Dir["skills/acli*"]
  end

  test do
    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    assert_predicate bin/"acli", :symlink?
    assert_match "acli #{version}", shell_output("#{bin}/acli --version")
    assert_match "aclid #{version}", shell_output("#{bin}/aclid --version")
    assert_match "brew upgrade artagon/aitools/acli", shell_output("#{bin}/acli self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/acli", shell_output("#{bin}/acli update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/acli", shell_output("#{bin}/aclid self-update 2>&1", 2)
    assert_match "brew upgrade artagon/aitools/acli", shell_output("#{bin}/aclid update 2>&1", 2)
    assert_path_exists pkgshare/"skills/acli-messaging/SKILL.md"
    if OS.mac? && Hardware::CPU.arm?
      require "macho"
      require "openssl"
      require "plist"
      shim = opt_libexec/"bin/acli-shim"
      system "/usr/bin/codesign", "--verify", "--verbose", shim
      cs_info = shell_output("/usr/bin/codesign -dvv #{shim} 2>&1")
      assert_equal "com.artagon.acli.shim", cs_info[/^Identifier=(.+)$/, 1]
      # Negative same-prefix fixture: suffixed identifier MUST NOT match exact equality
      bad_shim = testpath/"acli-shim-bad"
      cp shim, bad_shim
      chmod 0755, bad_shim
      system "/usr/bin/codesign", "--force", "--sign", "-", "--id", "com.artagon.acli.shim.backup", bad_shim
      bad_info = shell_output("/usr/bin/codesign -dvv #{bad_shim} 2>&1")
      refute_equal "com.artagon.acli.shim", bad_info[/^Identifier=(.+)$/, 1]

      lc = MachO.open(shim.to_s)[:LC_CODE_SIGNATURE].first
      sb = File.binread(shim.to_s, lc.datasize, lc.dataoff)
      _, _, count = sb.unpack("N3")
      slots = (0...count).to_h { |i| sb.byteslice(12 + (i * 8), 8).unpack("N2") }
      m5, l5 = sb.byteslice(slots.fetch(5), 8).unpack("N2")
      m7, l7 = sb.byteslice(slots.fetch(7), 8).unpack("N2")
      assert_equal 0xfade7171, m5
      assert_equal 0xfade7172, m7
      xml_map = Plist.parse_xml(sb.byteslice(slots.fetch(5) + 8, l5 - 8))
      der_seq = OpenSSL::ASN1.decode(sb.byteslice(slots.fetch(7) + 8, l7 - 8)).value[1].value
      der_map = der_seq.to_h { |seq| [seq.value[0].value, seq.value[1].value] }
      assert_equal({ "com.apple.security.hypervisor" => true }, xml_map)
      assert_equal({ "com.apple.security.hypervisor" => true }, der_map)
    end
    assert_match "ok", shell_output("#{bin}/acli bus self-test --isolated-run-dir #{testpath}/run")
    if (OS.mac? && Hardware::CPU.arm? && Utils.safe_popen_read("/usr/sbin/sysctl", "-n", "kern.hv_support").strip == "1") ||
       (OS.linux? && File.writable?("/dev/kvm"))
      system bin/"acli", "vm", "self-test", "--check-hypervisor"
    end
  end
end
```

---

## 4. Per-Artifact/Platform `versions/aitools-lock.json`, Pure-Rust Telemetry Packaging, & `--option builders ''` Nix Parity

1. **Per-Artifact/Platform `versions/aitools-lock.json`:** Keys every consumed archive by **`(package, artifact_role, platform)`** (**all 4 `agent-mail 0.3.41` archives, all 4 `br 0.7.6` archives, all 4 `bd 1.3.4` archives**, `nats 0.5.2`, `nats-server 2.15.3`, `acli` source, and both `acli` static musl guest `resource`s) alongside a separate `nix_closure` section (`flake.lock` rev, `vendorHash`, guest `.drv` identity), gated in CI by `scripts/check-aitools-lock.sh` and `scripts/autobump.sh` under stock **`--option builders ''`** (`ACLIVM01` handshake exits `70` on manifest digest drift).
2. **Guest Shared VM EROFS Exclusions (`~145 MiB` Saved) & Per-Arch Linux `bd` Nix ELF Relocation (`SOL-R11-02`):** Both **`bd` (`137.5–147.4 MiB` glibc ELF) and `br` stay OUT of the guest `acli-vm` EROFS closure** because guest panes cannot open read-only `/workspace/.beads` directly (`rc=1` `EACCES`/`EROFS`) and traverse static musl `acli msg bead` / `bus_bead` -> `vsock:5040` -> host `aclid` (with a 10-line guest `/bin/sh` stub `bd`/`br` exiting `2` pointing to `acli msg bead`; static Go `bv 0.27.0` may optionally ship in guest EROFS reading `/workspace/.beads/issues.jsonl`). For host Linux Nix / `agents-nix` `devShell` parity under `--option builders ''`, per-architecture ELF dependencies (`x86_64-linux`: `DT_NEEDED = [libc.so.6]` + `PT_INTERP = /lib64/ld-linux-x86-64.so.2`; `aarch64-linux`: `DT_NEEDED = [libc.so.6, ld-linux-aarch64.so.1]` + `PT_INTERP = /lib/ld-linux-aarch64.so.1`) are patched on `pkgsHost` via **`${pkgsHost.patchelf}/bin/patchelf --set-interpreter "${pkgsHost.glibc}/lib/ld-linux-..." --set-rpath "${pkgsHost.glibc}/lib"` (`pkgsHost == pkgsLinux` on native Linux `devShell`)** and wrapped with unconditional **`export BD_DISABLE_METRICS=1 BD_DISABLE_EVENT_FLUSH=1 DOLT_METRICS_DISABLED=1 DO_NOT_TRACK=1`** (`SOL-R12-01`); **native Linux cold-store execution (`ldd`/interpreter check, `bd --version`, and isolated embedded-Dolt smoke) is `not checked` on Darwin and is gated as a separate native `x86_64-linux` / `aarch64-linux` CI step** distinct from the Darwin EROFS substitution gate.
3. **Pure-Rust Core Store vs Optional Companion DuckDB (`SOL-R11-01`):** Core `acli`, `aclid`, and static musl `acli-guest-proxy` (`vsock:5050`) implement OTLP protobuf codecs (`prost`), 4-stage Rust DLP scrubbing, JSON + 5-table Apache Parquet + SQLite `store.db` compaction, and `otlp-ring` persistence in **pure Rust** (`0` Python, DuckDB, PyArrow, or `ELv2` runtime bloat in `Formula/acli.rb` or guest EROFS), while optional `store.duckdb` materialization and read-only DuckDB analytical queries belong **exclusively** to optional `Formula/artagon-harness-eval.rb` (`skillopt.rb` `uv tool install` + `@rpath` Mach-O normalization + 4-step SPDX license gate excluding `ELv2` `arize-phoenix` server wheels) alongside existing `<tap-root>/Formula/{phoenix-cli,arize-phoenix,langfuse-cli,openlit,mlflow}.rb`.
