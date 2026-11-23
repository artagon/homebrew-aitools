# Validate top-level schema, nix_closure, uniqueness, version consistency, and
# per-artifact fields of versions/aitools-lock.json with strict type guards so
# malformed JSON never aborts jq before emit_result emits --json.
# Expects --arg schema <expected>.
def is_str: type == "string";
def str_matches($re): is_str and test($re);

if type != "object" then
  ["lockfile root must be a JSON object"]
else
  [
    if ((.schema | is_str | not) or (.schema != $schema)) then
      "unexpected schema: expected \($schema), got \(.schema // "<missing>")"
    else empty end,

    if (.artifacts | type) != "array" or (.artifacts | length) == 0 then
      "artifacts must be a non-empty array"
    else empty end,

    if (.nix_closure | type) != "object" then
      "nix_closure must be an object"
    else
      (
        if ((.nix_closure.status | is_str | not) or (.nix_closure.status | IN("present", "staged") | not)) then
          "nix_closure.status must be \"present\" or \"staged\""
        else empty end,
        if ((.nix_closure.excluded_from_guest_erofs | type) != "array") or
           ((.nix_closure.excluded_from_guest_erofs | index("bd")) == null) or
           ((.nix_closure.excluded_from_guest_erofs | index("br")) == null) then
          "nix_closure.excluded_from_guest_erofs must include both \"bd\" and \"br\""
        else empty end,
        if (.nix_closure | has("flake_lock_rev") and has("vendor_hash") and has("guest_drv_identity") | not) then
          "nix_closure must declare flake_lock_rev, vendor_hash, and guest_drv_identity"
        else empty end,
        if (.nix_closure | has("acli_cargo_lock")) and (.nix_closure.acli_cargo_lock != null) then
          (
            if (.nix_closure.acli_cargo_lock | is_str | not) or
               (.nix_closure.acli_cargo_lock | startswith("/")) or
               (.nix_closure.acli_cargo_lock | split("/") | any(. == ".." or . == "")) or
               (.nix_closure.acli_cargo_lock | test("^[A-Za-z0-9._/-]+$") | not) then
              "nix_closure.acli_cargo_lock must be a safe repo-relative path without leading / or .."
            else empty end
          )
        else empty end,
        if (.nix_closure.status | is_str) and .nix_closure.status == "present" then
          (
            if (.nix_closure.flake_lock_rev | str_matches("^[0-9a-f]{40}$") | not) then
              "nix_closure.flake_lock_rev must be a 40-hex commit SHA when status is present"
            else empty end,
            if (.nix_closure.vendor_hash | str_matches("^sha256-[A-Za-z0-9+/]+=*$") | not) then
              "nix_closure.vendor_hash must be a sha256-... SRI hash when status is present"
            else empty end,
            if (.nix_closure.guest_drv_identity | is_str) then
              (if (.nix_closure.guest_drv_identity | length) == 0 then
                "nix_closure.guest_drv_identity must be non-empty when status is present"
              else empty end)
            elif (.nix_closure.guest_drv_identity | type) == "object" then
              (if ((.nix_closure.guest_drv_identity["aarch64-linux"] | is_str | not) or ((.nix_closure.guest_drv_identity["aarch64-linux"] | length) == 0)) or
                  ((.nix_closure.guest_drv_identity["x86_64-linux"] | is_str | not) or ((.nix_closure.guest_drv_identity["x86_64-linux"] | length) == 0)) then
                "nix_closure.guest_drv_identity object must specify non-empty aarch64-linux and x86_64-linux entries"
              else empty end)
            else
              "nix_closure.guest_drv_identity must be a non-empty string or per-arch object when status is present"
            end
          )
        else empty end
      )
    end,

    if (.artifacts | type) == "array" then
      (
        (.artifacts | to_entries[] | .key as $idx | .value |
          if type != "object" then
            "artifacts[\($idx)]: entry must be a JSON object"
          else
            (
              if (.package | str_matches("^[a-z0-9][a-z0-9@._+-]*$") | not) then
                "artifacts[\($idx)]: invalid package name"
              else empty end,
              if (.version | str_matches("^[0-9][0-9A-Za-z.+_-]{0,63}$") | not) then
                "artifacts[\($idx)] (\(.package // "?")): invalid version"
              else empty end,
              if ((.artifact_role | is_str | not) or (.artifact_role | IN("source", "binary", "guest-musl", "resource") | not)) then
                "artifacts[\($idx)] (\(.package // "?")): invalid artifact_role"
              else empty end,
              if ((.platform | is_str | not) or (.platform | IN("all", "darwin-arm64", "darwin-x86_64", "linux-arm64", "linux-x86_64") | not)) then
                "artifacts[\($idx)] (\(.package // "?")): invalid platform"
              else empty end,
              if ((.status | is_str | not) or (.status | IN("present", "staged") | not)) then
                "artifacts[\($idx)] (\(.package // "?")): status must be \"present\" or \"staged\""
              else empty end,
              if (.package | is_str) and ((.formula | is_str | not) or (.formula != ("Formula/" + .package + ".rb"))) then
                "artifacts[\($idx)] (\(.package)): formula must be Formula/\(.package).rb"
              else empty end,
              if (.artifact_role | is_str) and ((.artifact_role == "guest-musl") or (.artifact_role == "resource")) and ((.resource | is_str | not) or ((.resource | length) == 0)) then
                "artifacts[\($idx)] (\(.package // "?")): \(.artifact_role) entry requires non-empty resource name"
              else empty end,
              if (.artifact_role | is_str) and ((.artifact_role == "source") or (.artifact_role == "binary")) and (.resource != null) and ((.resource | is_str | not) or ((.resource | length) > 0)) then
                "artifacts[\($idx)] (\(.package // "?")): \(.artifact_role) entry must not set resource"
              else empty end,
              if (.status | is_str) and .status == "present" then
                (
                  if (.url | str_matches("^https://") | not) then
                    "artifacts[\($idx)] (\(.package // "?") \(.artifact_role // "?") \(.platform // "?")): present entry requires https:// url"
                  else empty end,
                  if (.sha256 | str_matches("^[0-9a-f]{64}$") | not) then
                    "artifacts[\($idx)] (\(.package // "?") \(.artifact_role // "?") \(.platform // "?")): present entry requires 64-hex sha256"
                  else empty end
                )
              else empty end
            )
          end
        ),
        (
          [.artifacts[] | select(type == "object" and (.package | is_str) and (.artifact_role | is_str) and (.platform | is_str) and .artifact_role != "resource")]
          | group_by([.package, .artifact_role, .platform])
          | map(select(length > 1))
          | .[]
          | "duplicate artifact key (\(.[0].package), \(.[0].artifact_role), \(.[0].platform))"
        ),
        (
          [.artifacts[] | select(type == "object" and (.package | is_str) and (.artifact_role | is_str) and (.platform | is_str) and .artifact_role == "resource")]
          | group_by([.package, .artifact_role, .platform, (if .resource | is_str then .resource else "" end)])
          | map(select(length > 1))
          | .[]
          | "duplicate artifact key (\(.[0].package), \(.[0].artifact_role), \(.[0].platform)\(if (.[0].resource | is_str) and (.[0].resource | length) > 0 then ", resource=" + .[0].resource else "" end))"
        ),
        (
          [.artifacts[] | select(type == "object" and (.package | is_str) and (.version | is_str))]
          | group_by(.package)
          | map({package: .[0].package, versions: (map(.version) | unique)})
          | map(select((.versions | length) > 1))
          | .[]
          | "package \(.package) has inconsistent versions across entries: \(.versions | join(", "))"
        ),
        if ([.artifacts[] | select(type == "object" and (.package | is_str) and .package == "acli" and (.status | is_str) and .status == "present")] | length) > 0 and
           ((.nix_closure | type) == "object") and ((.nix_closure.status | is_str | not) or (.nix_closure.status != "present")) then
          "nix_closure.status must be \"present\" once acli entries are marked \"present\""
        else empty end
      )
    else empty end
  ]
end
| .[]
