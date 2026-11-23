# Parse every non-license (artifact_role, platform, resource, url, sha256, explicit_version)
# entry declared in a brew-style Homebrew formula file.
# Output TSV columns: artifact_role \t platform \t resource \t url \t sha256 \t explicit_version
BEGIN {
  in_skip = 0
  skip_indent = -1
  os_ctx = ""
  arch_ctx = ""
  res_ctx = ""
  class_ver = ""
  pending_url = ""
  pending_role = ""
  pending_plat = ""
  pending_res = ""
  pending_ver = ""
}
function indent_of(s) {
  match(s, /^[ ]*/)
  return RLENGTH
}
function flush_error(msg) {
  printf "ERROR\t%s\n", msg
  exit 1
}
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
/^__END__$/ { exit }
{
  sub(/\r$/, "")
  ind = indent_of($0)
  if (in_skip) {
    if ($0 ~ /^[ ]*end$/ && ind == skip_indent) {
      in_skip = 0
      skip_indent = -1
    }
    next
  }

  if (ind == 2 && ($0 ~ /^  (bottle|livecheck|test|caveats|service|head|patch) do$/ || $0 ~ /^  def [A-Za-z_]/)) {
    in_skip = 1
    skip_indent = 2
    next
  }

  if (ind == 2 && $0 ~ /^  version "[^"]+"$/ && pending_url == "" && os_ctx == "" && res_ctx == "") {
    v = $0
    sub(/^  version "/, "", v)
    sub(/"$/, "", v)
    class_ver = v
    next
  }

  if (ind == 2 && $0 == "  on_macos do") {
    os_ctx = "darwin"
    arch_ctx = ""
    next
  }
  if (ind == 2 && $0 == "  on_linux do") {
    os_ctx = "linux"
    arch_ctx = ""
    next
  }
  if ($0 ~ /^[ ]*resource "[^"]+" do$/) {
    if (ind != 2 || os_ctx != "") {
      flush_error("unsupported nested resource block: " $0)
    }
    line = $0
    sub(/^  resource "/, "", line)
    sub(/" do$/, "", line)
    res_ctx = line
    os_ctx = ""
    arch_ctx = ""
    next
  }
  if (ind == 4 && os_ctx != "" && $0 == "    on_arm do") {
    arch_ctx = "arm64"
    next
  }
  if (ind == 4 && os_ctx != "" && $0 == "    on_intel do") {
    arch_ctx = "x86_64"
    next
  }
  if ($0 == "    end" && arch_ctx != "") {
    arch_ctx = ""
    next
  }
  if ($0 == "  end") {
    os_ctx = ""
    arch_ctx = ""
    res_ctx = ""
    next
  }

  if (pending_url != "") {
    if ($0 ~ /^[ ]*version "[^"]+"$/) {
      v = $0
      sub(/^[ ]*version "/, "", v)
      sub(/"$/, "", v)
      pending_ver = v
      next
    }
    if ($0 ~ /^[ ]*sha256 "[0-9a-f]{64}"$/) {
      sha = $0
      sub(/^[ ]*sha256 "/, "", sha)
      sub(/"$/, "", sha)
      eff_ver = (pending_ver != "") ? pending_ver : class_ver
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", pending_role, pending_plat, pending_res, pending_url, sha, eff_ver
      pending_url = ""
      pending_role = ""
      pending_plat = ""
      pending_res = ""
      pending_ver = ""
      next
    }
    flush_error("missing sha256 after url " pending_url)
  }

  if ($0 ~ /^[ ]*url[[:space:]]/) {
    if (res_ctx == "license") {
      next
    }
    if ($0 !~ /^[ ]*url "[^"]+"$/) {
      flush_error("unsupported url declaration format: " $0)
    }
    url = $0
    sub(/^[ ]*url "/, "", url)
    sub(/"$/, "", url)

    role = "source"
    plat = "all"
    res = ""

    if (res_ctx != "") {
      res = res_ctx
      if (res_ctx == "guest-aarch64-linux-musl") {
        role = "guest-musl"
        plat = "linux-arm64"
      } else if (res_ctx == "guest-x86_64-linux-musl") {
        role = "guest-musl"
        plat = "linux-x86_64"
      } else {
        role = "resource"
        plat = "all"
      }
    } else if (os_ctx != "") {
      if (arch_ctx == "") {
        flush_error("url inside on_macos/on_linux without on_arm/on_intel: " url)
      }
      role = "binary"
      plat = os_ctx "-" arch_ctx
    }

    pending_url = url
    pending_role = role
    pending_plat = plat
    pending_res = res
    pending_ver = ""
    next
  }
}
END {
  if (pending_url != "") {
    flush_error("unterminated url without sha256: " pending_url)
  }
}
