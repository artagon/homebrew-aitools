# Co-update versions/aitools-lock.json entries for a present tracked formula.
# Expects --arg pkg <name> --arg ver <version> --argjson rows <array>.
.artifacts |= map(
  if .package == $pkg and .status == "present" then
    . as $entry
    | ($rows | map(select(.artifact_role == $entry.artifact_role and .platform == $entry.platform and .resource == ($entry.resource // "")))) as $m
    | if ($m | length) == 1 then
        .version = $ver
        | .url = $m[0].url
        | .sha256 = $m[0].sha256
      else
        error("missing matching artifact row for \($pkg) \($entry.artifact_role) \($entry.platform)")
      end
  else
    .
  end
)
