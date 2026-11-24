class NatsServer < Formula
  desc "Lightweight cloud messaging system"
  homepage "https://nats.io"
  url "https://github.com/nats-io/nats-server/archive/refs/tags/v2.15.3.tar.gz"
  sha256 "034a2a7535d67ae6f28962976a530dad1bd912dd2d9af05a3990f3b7e674008e"
  license "Apache-2.0"
  head "https://github.com/nats-io/nats-server.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  # `test do` runs local loopback listeners on ephemeral ports.
  allow_network_access! :test
  deny_network_access! [:build, :postinstall]

  def fetch
    system "go", "mod", "download"
  end

  def install
    # Build upstream nats-server unmodified before adding preflight helper files.
    system "go", "build", *std_go_args(output: libexec/"nats-server")

    (buildpath/"conf/preflight_keys.go").write <<~GO
      package conf

      import (
      	"fmt"
      	"os"
      	"path/filepath"
      	"strings"
      )

      // TopLevelKeyCounts lexes fp (and recursively any top-level include files)
      // using nats-server's native conf lexer and returns case-folded occurrence
      // counts of every top-level key before Go map merging collapses exact-case
      // duplicates.
      func TopLevelKeyCounts(fp string) (map[string]int, error) {
      	counts := make(map[string]int)
      	visiting := make(map[string]bool)
      	if err := countTopLevelKeys(fp, counts, visiting); err != nil {
      		return nil, err
      	}
      	return counts, nil
      }

      func countTopLevelKeys(fp string, counts map[string]int, visiting map[string]bool) error {
      	abs, err := filepath.Abs(fp)
      	if err != nil {
      		abs = filepath.Clean(fp)
      	}
      	if visiting[abs] {
      		return fmt.Errorf("cyclic include detected for %s", fp)
      	}
      	visiting[abs] = true
      	defer delete(visiting, abs)

      	data, err := os.ReadFile(fp)
      	if err != nil {
      		return err
      	}

      	lx := lex(string(data))
      	depth := 0
      	baseDir := filepath.Dir(fp)
      	for {
      		it := lx.nextItem()
      		switch it.typ {
      		case itemEOF:
      			return nil
      		case itemError:
      			return fmt.Errorf("parse error in %s:%d: %s", fp, it.line, it.val)
      		case itemMapStart, itemArrayStart:
      			depth++
      		case itemMapEnd, itemArrayEnd:
      			if depth > 0 {
      				depth--
      			}
      		case itemKey:
      			if depth == 0 && it.val != mapEndString {
      				counts[strings.ToLower(it.val)]++
      			}
      		case itemInclude:
      			if depth == 0 {
      				incPath := filepath.Join(baseDir, it.val)
      				if err := countTopLevelKeys(incPath, counts, visiting); err != nil {
      					return err
      				}
      			}
      		}
      	}
      }
    GO

    preflight_dir = buildpath/"cmd/nats-bind-preflight"
    preflight_dir.mkpath
    (preflight_dir/"main.go").write <<~'GO'
      package main

      import (
      	"fmt"
      	"os"
      	"path/filepath"
      	"strconv"
      	"strings"
      	"syscall"

      	"github.com/nats-io/nats-server/v2/conf"
      	"github.com/nats-io/nats-server/v2/server"
      )

      const exitAmbiguousBind = 78

      var boolFlags = map[string]struct{}{
      	"h":            {},
      	"help":         {},
      	"D":            {},
      	"debug":        {},
      	"V":            {},
      	"VV":           {},
      	"trace":        {},
      	"DV":           {},
      	"DVV":          {},
      	"T":            {},
      	"logtime":      {},
      	"logtime_utc":  {},
      	"t":            {},
      	"s":            {},
      	"syslog":       {},
      	"version":      {},
      	"v":            {},
      	"no_advertise": {},
      	"help_tls":     {},
      	"tls":          {},
      	"tlsverify":    {},
      	"js":           {},
      	"jetstream":    {},
      }

      var valuedFlags = map[string]struct{}{
      	"port":               {},
      	"p":                  {},
      	"n":                  {},
      	"name":               {},
      	"server_name":        {},
      	"addr":               {},
      	"a":                  {},
      	"net":                {},
      	"client_advertise":   {},
      	"user":               {},
      	"pass":               {},
      	"auth":               {},
      	"m":                  {},
      	"http_port":          {},
      	"ms":                 {},
      	"https_port":         {},
      	"c":                  {},
      	"config":             {},
      	"test_reload":        {},
      	"sl":                 {},
      	"signal":             {},
      	"P":                  {},
      	"pid":                {},
      	"ports_file_dir":     {},
      	"l":                  {},
      	"log":                {},
      	"log_size_limit":     {},
      	"r":                  {},
      	"remote_syslog":      {},
      	"profile":            {},
      	"routes":             {},
      	"cluster":            {},
      	"cluster_listen":     {},
      	"cluster_advertise":  {},
      	"connect_retries":    {},
      	"cluster_name":       {},
      	"tlscert":            {},
      	"tlskey":             {},
      	"tlscacert":          {},
      	"max_traced_msg_len": {},
      	"sd":                 {},
      	"store_dir":          {},
      }

      type configBindInfo struct {
      	hasAddr  bool
      	hasPort  bool
      	js       bool
      	storeDir string
      }

      func inspectConfigFile(path string) (info configBindInfo, passthrough bool, exitCode int, errMsg string) {
      	counts, err := conf.TopLevelKeyCounts(path)
      	if err != nil {
      		return info, true, 0, ""
      	}

      	addrSetters := counts["host"] + counts["net"] + counts["listen"]
      	portSetters := counts["port"] + counts["listen"]
      	if addrSetters > 1 {
      		return info, false, exitAmbiguousBind, fmt.Sprintf(
      			"nats-server: E78:ambiguous_nats_bind: multiple top-level client address directives in %s",
      			path,
      		)
      	}
      	if portSetters > 1 {
      		return info, false, exitAmbiguousBind, fmt.Sprintf(
      			"nats-server: E78:ambiguous_nats_bind: multiple top-level client port directives in %s",
      			path,
      		)
      	}

      	opts, err := server.ProcessConfigFile(path)
      	if err != nil {
      		return info, true, 0, ""
      	}

      	info.hasAddr = strings.TrimSpace(opts.Host) != ""
      	info.hasPort = opts.Port != 0
      	info.js = opts.JetStream
      	info.storeDir = strings.TrimSpace(opts.StoreDir)
      	return info, false, 0, ""
      }

      func resolveArgs(args []string, getenv func(string) string) (out []string, passthrough bool, exitCode int, errMsg string) {
      	var (
      		cliAddrSet     bool
      		cliAddrVal     string
      		cliPortSet     bool
      		cliConfigSet   bool
      		cliConfigVal   string
      		cliTestReload  string
      		cliStoreDirSet bool
      		cliStoreDirVal string
      		cliJSSet       bool
      		cliJSVal       bool
      		cliSignalVal   string
      		showHelp       bool
      		showVersion    bool
      		showTLSHelp    bool
      		positionalMeta bool
      	)

      	optionSegmentEnd := len(args)
      	for i := 0; i < len(args); i++ {
      		arg := args[i]
      		if arg == "--" {
      			optionSegmentEnd = i
      			if i+1 < len(args) {
      				firstPos := args[i+1]
      				if strings.EqualFold(firstPos, "version") || strings.EqualFold(firstPos, "help") {
      					positionalMeta = true
      				}
      			}
      			break
      		}
      		if len(arg) < 2 || arg[0] != '-' {
      			optionSegmentEnd = i
      			if strings.EqualFold(arg, "version") || strings.EqualFold(arg, "help") {
      				positionalMeta = true
      			}
      			break
      		}

      		numMinuses := 1
      		if arg[1] == '-' {
      			numMinuses = 2
      		}
      		name := arg[numMinuses:]
      		if len(name) == 0 || name[0] == '-' || name[0] == '=' {
      			return args, true, 0, ""
      		}

      		hasValue := false
      		val := ""
      		if eq := strings.IndexByte(name, '='); eq >= 0 {
      			val = name[eq+1:]
      			name = name[:eq]
      			hasValue = true
      		}

      		if _, isBool := boolFlags[name]; isBool {
      			bval := true
      			if hasValue {
      				if name == "tlsverify" && strings.EqualFold(val, "optional") {
      					bval = true
      				} else {
      					parsed, err := strconv.ParseBool(val)
      					if err != nil {
      						return args, true, 0, ""
      					}
      					bval = parsed
      				}
      			}
      			switch name {
      			case "h", "help":
      				showHelp = bval
      			case "v", "version":
      				showVersion = bval
      			case "help_tls":
      				showTLSHelp = bval
      			case "js", "jetstream":
      				cliJSSet = true
      				cliJSVal = bval
      			}
      			continue
      		}

      		if _, isValued := valuedFlags[name]; isValued {
      			if !hasValue {
      				if i+1 >= len(args) {
      					return args, true, 0, ""
      				}
      				i++
      				val = args[i]
      			}
      			switch name {
      			case "a", "addr", "net":
      				cliAddrSet = true
      				cliAddrVal = val
      			case "p", "port":
      				cliPortSet = true
      			case "c", "config":
      				cliConfigSet = true
      				cliConfigVal = val
      			case "test_reload":
      				cliTestReload = val
      			case "sd", "store_dir":
      				cliStoreDirSet = true
      				cliStoreDirVal = val
      			case "sl", "signal":
      				cliSignalVal = val
      			}
      			continue
      		}

      		return args, true, 0, ""
      	}

      	if showHelp || showVersion || showTLSHelp || positionalMeta || cliSignalVal != "" {
      		return args, true, 0, ""
      	}

      	if cliAddrSet && strings.TrimSpace(cliAddrVal) == "" {
      		return nil, false, exitAmbiguousBind, "nats-server: E78:ambiguous_nats_bind: empty CLI bind address"
      	}

      	var cfgInfo configBindInfo
      	if cliConfigSet && cliConfigVal != "" {
      		info, pt, code, msg := inspectConfigFile(cliConfigVal)
      		if code != 0 {
      			return nil, false, code, msg
      		}
      		if pt {
      			return args, true, 0, ""
      		}
      		cfgInfo = info
      	}

      	if cliTestReload != "" {
      		_, _, code, msg := inspectConfigFile(cliTestReload)
      		if code != 0 {
      			return nil, false, code, msg
      		}
      	}

      	var injected []string
      	if !cliAddrSet && !cfgInfo.hasAddr {
      		injected = append(injected, "--addr", "127.0.0.1")
      	}
      	if !cliPortSet && !cfgInfo.hasPort {
      		injected = append(injected, "-p", "4222")
      	}

      	effectiveJS := cfgInfo.js
      	if cliJSSet {
      		effectiveJS = cliJSVal
      	}
      	effectiveStoreDir := cfgInfo.storeDir
      	if cliStoreDirSet {
      		effectiveStoreDir = strings.TrimSpace(cliStoreDirVal)
      	}
      	if effectiveJS && effectiveStoreDir == "" {
      		stateHome := strings.TrimSpace(getenv("XDG_STATE_HOME"))
      		if stateHome == "" {
      			home := strings.TrimSpace(getenv("HOME"))
      			if home != "" {
      				stateHome = filepath.Join(home, ".local", "state")
      			}
      		}
      		if stateHome != "" {
      			injected = append(injected, "--store_dir", filepath.Join(stateHome, "nats", "jetstream"))
      		}
      	}

      	out = make([]string, 0, len(args)+len(injected))
      	out = append(out, args[:optionSegmentEnd]...)
      	out = append(out, injected...)
      	out = append(out, args[optionSegmentEnd:]...)
      	return out, false, 0, ""
      }

      func main() {
      	if len(os.Args) < 2 {
      		fmt.Fprintln(os.Stderr, "nats-bind-preflight: missing nats-server binary path")
      		os.Exit(2)
      	}
      	serverBin := os.Args[1]
      	resolved, _, exitCode, errMsg := resolveArgs(os.Args[2:], os.Getenv)
      	if exitCode != 0 {
      		fmt.Fprintln(os.Stderr, errMsg)
      		os.Exit(exitCode)
      	}
      	execArgv := make([]string, 0, 1+len(resolved))
      	execArgv = append(execArgv, serverBin)
      	execArgv = append(execArgv, resolved...)
      	if err := syscall.Exec(serverBin, execArgv, os.Environ()); err != nil {
      		fmt.Fprintf(os.Stderr, "nats-bind-preflight: exec %s: %v\n", serverBin, err)
      		os.Exit(126)
      	}
      }
    GO

    system "go", "build", *std_go_args(output: libexec/"bin/nats-bind-preflight"), "./cmd/nats-bind-preflight"
    chmod 0755, [libexec/"nats-server", libexec/"bin/nats-bind-preflight"]

    (bin/"nats-server").write <<~SH
      #!/bin/bash
      # Target contract: macOS /bin/bash 3.2+ wrapper.
      set -euo pipefail

      export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

      exec "#{libexec}/bin/nats-bind-preflight" "#{libexec}/nats-server" "$@"
    SH
    chmod 0755, bin/"nats-server"
  end

  def caveats
    <<~EOS
      Because `homebrew/core` also provides a `nats-server` formula, always
      qualify this tap when installing or upgrading:
        brew install artagon/aitools/nats-server
        brew upgrade artagon/aitools/nats-server

      The `nats-server` wrapper resolves client bind address and port
      independently via `#{opt_libexec}/bin/nats-bind-preflight`:
        - Defaults client address to `127.0.0.1` and port to `4222` when unset.
        - Exits `78` (`E78:ambiguous_nats_bind`) on empty CLI bind addresses or
          duplicate top-level client address/port directives in config files.
        - Defaults JetStream `--store_dir` to
          `${XDG_STATE_HOME:-$HOME/.local/state}/nats/jetstream` when `-js` is
          enabled without an explicit store directory.

      This formula installs no background service and modifies no user or agent
      configuration files.
    EOS
  end

  test do
    require "net/http"

    ENV["HOME"] = testpath.to_s
    ENV["XDG_CONFIG_HOME"] = (testpath/".config").to_s
    ENV["XDG_STATE_HOME"] = (testpath/".local/state").to_s

    assert_match version.to_s, shell_output("#{bin}/nats-server --version")

    # Blank/whitespace effective CLI bind addresses and negated-meta bypasses MUST exit 78.
    assert_match "E78:ambiguous_nats_bind", shell_output("#{bin}/nats-server -a '' 2>&1", 78)
    assert_match "E78:ambiguous_nats_bind", shell_output("#{bin}/nats-server --addr= 2>&1", 78)
    assert_match "E78:ambiguous_nats_bind", shell_output("#{bin}/nats-server --net='  ' 2>&1", 78)
    assert_match "E78:ambiguous_nats_bind", shell_output("#{bin}/nats-server -a 127.0.0.1 --net '' 2>&1", 78)
    assert_match "E78:ambiguous_nats_bind", shell_output("#{bin}/nats-server -v -v=false -a '' 2>&1", 78)
    assert_match "E78:ambiguous_nats_bind", shell_output("#{bin}/nats-server -h -h=false --addr= 2>&1", 78)
    assert_match "E78:ambiguous_nats_bind",
                 shell_output("#{bin}/nats-server --help_tls --help_tls=false -a '' 2>&1", 78)
    assert_match "E78:ambiguous_nats_bind", shell_output("#{bin}/nats-server -sl reload -sl '' -a '' 2>&1", 78)

    # Cross-key, exact-case, JSON, and include duplicate top-level directives MUST exit 78.
    (testpath/"dup_addr.conf").write("host: \"127.0.0.1\"\nnet: \"0.0.0.0\"\n")
    (testpath/"dup_same_host.conf").write("host: \"127.0.0.1\"\nhost: \"0.0.0.0\"\n")
    (testpath/"dup_same_port.conf").write("port: 4222\nport: 4223\n")
    (testpath/"dup_same_listen.conf").write("listen: \"127.0.0.1:4222\"\nlisten: \"0.0.0.0:4223\"\n")
    (testpath/"dup_json_host.conf").write("{\"host\": \"127.0.0.1\", \"host\": \"0.0.0.0\"}\n")
    (testpath/"dup_case.conf").write("HOST: \"127.0.0.1\"\nnet: \"0.0.0.0\"\n")
    (testpath/"dup_listen_host.conf").write("listen: \"127.0.0.1:4222\"\nhost: \"127.0.0.1\"\n")
    (testpath/"dup_listen_port.conf").write("listen: \"127.0.0.1:4222\"\nport: 4223\n")
    (testpath/"inc_sub_net.conf").write("NET: \"0.0.0.0\"\n")
    (testpath/"dup_include_net.conf").write("host: \"127.0.0.1\"\ninclude \"inc_sub_net.conf\"\n")
    (testpath/"inc_sub_host.conf").write("host: \"0.0.0.0\"\n")
    (testpath/"dup_include_host.conf").write("host: \"127.0.0.1\"\ninclude \"inc_sub_host.conf\"\n")
    %w[
      dup_addr.conf dup_same_host.conf dup_same_port.conf dup_same_listen.conf
      dup_json_host.conf dup_case.conf dup_listen_host.conf dup_listen_port.conf
      dup_include_net.conf dup_include_host.conf
    ].each do |cfg|
      assert_match "E78:ambiguous_nats_bind", shell_output("#{bin}/nats-server -t -c #{testpath}/#{cfg} 2>&1", 78)
    end

    valid_nested = testpath/"valid_nested.conf"
    valid_nested.write <<~CONF
      server_name: "brew_nested"
      host: "127.0.0.1"
      port: #{free_port}
      accounts { SYS {} }
      system_account: SYS
      jetstream { store_dir: "#{testpath}/js_nested" }
      leafnodes { host: "127.0.0.1", port: #{free_port} }
      cluster { name: "c1", listen: "127.0.0.1:#{free_port}" }
      gateway { name: "c1", listen: "127.0.0.1:#{free_port}" }
      websocket { listen: "127.0.0.1:#{free_port}", no_tls: true }
      mqtt { listen: "127.0.0.1:#{free_port}" }
    CONF
    system bin/"nats-server", "-t", "-c", valid_nested

    run_with_varz = lambda do |args|
      http_port = free_port
      pid = spawn(bin/"nats-server", *args, "-m", http_port.to_s)
      begin
        uri = URI("http://127.0.0.1:#{http_port}/varz")
        varz = nil
        50.times do
          varz = JSON.parse(Net::HTTP.get(uri))
          break
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError, JSON::ParserError
          sleep 0.1
        end
        raise "Timed out waiting for nats-server /varz on port #{http_port}" unless varz

        varz
      ensure
        begin
          Process.kill("TERM", pid)
        rescue Errno::ESRCH
          nil
        end
        begin
          Process.wait(pid)
        rescue Errno::ECHILD
          nil
        end
      end
    end

    hostless_conf = testpath/"hostless.conf"
    hostless_conf.write("server_name: brew_hostless\n")
    port1 = free_port
    varz1 = run_with_varz.call(["-v", "-v=false", "-n", "-a", "--port=#{port1}", "-c", hostless_conf.to_s])
    assert_equal "127.0.0.1", varz1["host"]
    assert_equal port1, varz1["port"]
    assert_equal version.to_s, varz1["version"]

    empty_host_conf = testpath/"empty_host.conf"
    empty_host_conf.write("host: \"\"\n")
    port2 = free_port
    varz2 = run_with_varz.call(["-p", port2.to_s, "-c", empty_host_conf.to_s, "-js"])
    assert_equal "127.0.0.1", varz2["host"]
    assert_equal port2, varz2["port"]
    assert_equal (testpath/".local/state/nats/jetstream/jetstream").to_s,
                 varz2.dig("jetstream", "config", "store_dir")

    listen_port_only = testpath/"listen_port_only.conf"
    port3 = free_port
    listen_port_only.write("listen: \":#{port3}\"\n")
    varz3 = run_with_varz.call(["-c", listen_port_only.to_s])
    assert_equal "127.0.0.1", varz3["host"]
    assert_equal port3, varz3["port"]

    port_only_conf = testpath/"port_only.conf"
    port4 = free_port
    port_only_conf.write("port: #{port4}\n")
    varz4 = run_with_varz.call(["--a", "127.0.0.1", "-c", port_only_conf.to_s])
    assert_equal "127.0.0.1", varz4["host"]
    assert_equal port4, varz4["port"]

    refute_path_exists testpath/".claude"
    refute_path_exists testpath/".codex"
    refute_path_exists testpath/".gemini"
    refute_path_exists testpath/".agents"
  end
end
