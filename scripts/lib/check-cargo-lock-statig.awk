# Verify Cargo.lock pins pure-Rust statig == req_ver (with no other statig version)
# and contains zero commercial statsig* crates (case-insensitive).
BEGIN {
  in_pkg = 0
  pkg_name = ""
  pkg_ver = ""
  statig_ok = 0
  statig_bad_vers = ""
  statsig_found = ""
}
function flush_pkg() {
  if (!in_pkg) {
    return
  }
  if (pkg_name == "statig") {
    if (pkg_ver == req_ver) {
      statig_ok = 1
    } else {
      statig_bad_vers = (statig_bad_vers == "") ? pkg_ver : (statig_bad_vers ", " pkg_ver)
    }
  }
  if (tolower(pkg_name) ~ /^statsig/) {
    statsig_found = (statsig_found == "") ? pkg_name : (statsig_found ", " pkg_name)
  }
  pkg_name = ""
  pkg_ver = ""
}
{
  sub(/\r$/, "")
}
/^\[\[package\]\]$/ {
  flush_pkg()
  in_pkg = 1
  next
}
/^\[/ {
  flush_pkg()
  in_pkg = 0
  next
}
in_pkg && /^name = "/ {
  val = $0
  sub(/^name = "/, "", val)
  sub(/"$/, "", val)
  pkg_name = val
  next
}
in_pkg && /^version = "/ {
  val = $0
  sub(/^version = "/, "", val)
  sub(/"$/, "", val)
  pkg_ver = val
  next
}
END {
  flush_pkg()
  if (statsig_found != "") {
    printf "banned commercial statsig crate(s) found in Cargo.lock: %s\n", statsig_found
  }
  if (statig_bad_vers != "") {
    printf "Cargo.lock contains disallowed statig version(s): %s (required strictly %s)\n", statig_bad_vers, req_ver
  }
  if (!statig_ok) {
    printf "Cargo.lock is missing required pure-Rust statig %s pin\n", req_ver
  }
}
