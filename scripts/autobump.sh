#!/usr/bin/env bash
# Bump tap formulae that lag their upstream release; see docs/agent-context.md.
#
# Each formula's livecheck block finds the latest release. A bump points every
# url that names the current version at the new one and recomputes the sha256
# on the next line, so single-url and per-platform formulae bump the same way.
# A new upstream version drops any formula revision. A bump of the Java grammar
# also bumps the revision of each formula that compiles the grammar in.
#
# Usage: autobump.sh check [formula...]          list formulae with a newer release
#        autobump.sh write [formula...]          write the bumps, without Git
#        autobump.sh pr [--base BRANCH] [formula...]  open one pull request per bump (CI)
#        autobump.sh rewrite FILE OLD NEW        print FILE bumped from OLD to NEW
#
# Runs on macOS Bash 3.2 and Bash 5. Needs brew, jq, curl, shasum or sha256sum,
# and, for `pr`, git and gh.
set -euo pipefail

tap="artagon/aitools"
repo="$(cd "$(dirname "$0")/.." && pwd -P)"
formula_dir="${repo}/Formula"
grammar="tree-sitter-java-valhalla"

# Upstream controls tag names; they become branch names, URLs, and commit messages.
version_re='^[0-9][0-9A-Za-z.+_-]{0,63}$'
url_re='^([[:space:]]*)url "([^"]+)"$'
sha_re='^([[:space:]]*)sha256 "[0-9a-f]{64}"$'
revision_re='^  revision ([0-9]+)$'
license_re='^  license "[^"]*"$'
hash_re='^[0-9a-f]{64}$'

die() {
  printf 'autobump: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage: autobump.sh check [formula...]
       autobump.sh write [formula...]
       autobump.sh pr [--base BRANCH] [formula...]
       autobump.sh rewrite FILE OLD NEW
EOF
  exit 2
}

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    curl -fsSL --retry 3 --user-agent artagon-aitools-autobump "$1" | shasum -a 256 | awk '{ print $1 }'
  else
    curl -fsSL --retry 3 --user-agent artagon-aitools-autobump "$1" | sha256sum | awk '{ print $1 }'
  fi
}

# Print FILE with every url that names OLD moved to NEW and the sha256 after it refreshed.
bump_text() {
  local file="$1" old="$2" new="$3" line indent new_url pending="" changed=0 dropped=0
  # Versions hold no glob or `&` characters, so the substitution below is literal
  # in Bash 3.2 and 5 alike.
  [[ "${old}" =~ ${version_re} ]] || die "unexpected version: ${old}"
  [[ "${new}" =~ ${version_re} ]] || die "unexpected version: ${new}"
  while IFS= read -r line || [ -n "${line}" ]; do
    if [ -n "${pending}" ]; then
      [[ "${line}" =~ ${sha_re} ]] || die "no sha256 line after a url naming ${old} in ${file}"
      printf '%ssha256 "%s"\n' "${BASH_REMATCH[1]}" "${pending}"
      pending=""
      continue
    fi
    if [[ "${line}" =~ ${url_re} ]] && [[ "${BASH_REMATCH[2]}" == *"${old}"* ]]; then
      indent="${BASH_REMATCH[1]}"
      new_url="${BASH_REMATCH[2]//${old}/${new}}"
      pending="$(sha256_of "${new_url}")"
      [[ "${pending}" =~ ${hash_re} ]] || die "could not hash ${new_url}"
      printf '%surl "%s"\n' "${indent}" "${new_url}"
      changed=$((changed + 1))
      continue
    fi
    if [ "${dropped}" -eq 0 ] && [[ "${line}" =~ ${revision_re} ]]; then
      dropped=1
      continue
    fi
    printf '%s\n' "${line}"
  done < "${file}"
  [ "${changed}" -gt 0 ] || die "no url names version ${old} in ${file}"
}

# Print FILE with its revision incremented, or with `revision 1` added after its license.
bump_revision() {
  local file="$1" line done=0 had_revision=0
  if grep -Eq "${revision_re}" "${file}"; then
    had_revision=1
  fi
  while IFS= read -r line || [ -n "${line}" ]; do
    if [ "${had_revision}" -eq 1 ] && [ "${done}" -eq 0 ] && [[ "${line}" =~ ${revision_re} ]]; then
      printf '  revision %d\n' "$((BASH_REMATCH[1] + 1))"
      done=1
      continue
    fi
    printf '%s\n' "${line}"
    if [ "${had_revision}" -eq 0 ] && [ "${done}" -eq 0 ] && [[ "${line}" =~ ${license_re} ]]; then
      printf '  revision 1\n'
      done=1
    fi
  done < "${file}"
  [ "${done}" -eq 1 ] || die "no license line in ${file} to place a revision after"
}

# Print the formulae a bump of NAME changes: the formula, and its dependents for the grammar.
affected() {
  printf '%s\n' "$1"
  if [ "$1" = "${grammar}" ]; then
    printf '%s\n' ast-grep-valhalla ripwire
  fi
}

# Run COMMAND... and write its output over FILE.
replace_with() {
  local file="$1"
  shift
  "$@" > "${file}.autobump"
  mv "${file}.autobump" "${file}"
}

# Write the bump for NAME into the working tree.
apply_bump() {
  local name="$1" old="$2" new="$3" formula
  for formula in $(affected "${name}"); do
    if [ "${formula}" = "${name}" ]; then
      replace_with "${formula_dir}/${formula}.rb" bump_text "${formula_dir}/${formula}.rb" "${old}" "${new}"
    else
      replace_with "${formula_dir}/${formula}.rb" bump_revision "${formula_dir}/${formula}.rb"
    fi
  done
}

# Print "name<TAB>current<TAB>latest" for each formula with a newer upstream release.
outdated() {
  local json name old new
  local -a targets=(--tap "${tap}")
  if [ "$#" -gt 0 ]; then
    targets=()
    for name in "$@"; do
      targets+=("${tap}/${name}")
    done
  fi
  json="$(brew livecheck --formula --json --quiet --newer-only "${targets[@]}")"
  printf '%s' "${json:-[]}" | jq -r '.[] | select(.status == "error") | "livecheck error: \(.)"' >&2
  printf '%s' "${json:-[]}" |
    jq -r '.[] | select(.version.outdated == true)
           | [(.formula | split("/") | last), .version.current, .version.latest] | @tsv' |
    while IFS=$'\t' read -r name old new; do
      [ -f "${formula_dir}/${name}.rb" ] || die "livecheck named an unknown formula: ${name}"
      if [[ ! "${old}" =~ ${version_re} ]] || [[ ! "${new}" =~ ${version_re} ]] || [[ "${new}" == *..* ]]; then
        die "refusing unexpected version for ${name}: ${new}"
      fi
      printf '%s\t%s\t%s\n' "${name}" "${old}" "${new}"
    done
}

# Open one pull request for a bump. Runs in its own process, so a failure stops
# only this bump: `pr` restores the base branch and moves on.
open_pull_request() {
  local name="$1" old="$2" new="$3" base="$4" branch formula formulae=""
  local -a paths=()
  branch="bump/${name}-${new}"
  if [ -n "$(git ls-remote --heads origin "${branch}")" ]; then
    printf '%s: branch %s already exists\n' "${name}" "${branch}"
    return 0
  fi
  git switch --create "${branch}" "origin/${base}"
  apply_bump "${name}" "${old}" "${new}"
  for formula in $(affected "${name}"); do
    paths+=("Formula/${formula}.rb")
    formulae="${formulae:+${formulae} }${tap}/${formula}"
  done
  brew style "${paths[@]}"
  git add -- "${paths[@]}"
  git commit --message "${name} ${new}"
  git push origin "${branch}"
  gh pr create --base "${base}" --head "${branch}" --title "${name} ${new}" --body "$(cat <<EOF
Upstream released ${name} ${new}; the formula had ${old}.

Opened by \`scripts/autobump.sh\`, which dispatched the \`brew test-bot\` workflow
to build, test, and bottle ${formulae}. When it passes, review the diff and
publish with \`gh workflow run publish.yml -f pull_request=<this PR number> -f head_sha=<reviewed commit>\`.
Do not merge this pull request directly: the formula would ship without bottles.

A Ripwire bump fails the installer integration suite on purpose when the
bundled installer or skill set changes: review the payload, then update the
pins in \`tests/integration_agent_install.py\`.
EOF
)"
  # Events from GITHUB_TOKEN start no pull_request run; a dispatch is allowed, and
  # brew pr-pull finds its bottles through the check suite on the branch head.
  gh workflow run tests.yml --ref "${branch}" -f "formulae=${formulae}"
  git switch "${base}"
}

main() {
  local command base="main" name old new failures=0
  [ "$#" -gt 0 ] || usage
  command="$1"
  shift
  cd "${repo}"
  case "${command}" in
    rewrite)
      [ "$#" -eq 3 ] || usage
      bump_text "$1" "$2" "$3"
      ;;
    _pr_one)
      open_pull_request "$@"
      ;;
    _revision)
      [ "$#" -eq 1 ] || usage
      bump_revision "$1"
      ;;
    check | write | pr)
      if [ "${command}" = pr ] && [ "${1:-}" = --base ]; then
        [ "$#" -ge 2 ] || usage
        base="$2"
        shift 2
      fi
      # Global, not local: the EXIT trap runs after main returns.
      list="$(mktemp)"
      trap 'rm -f "${list:-}"' EXIT
      outdated "$@" > "${list}"
      while IFS=$'\t' read -r name old new; do
        printf '%s: %s -> %s\n' "${name}" "${old}" "${new}"
        case "${command}" in
          write)
            apply_bump "${name}" "${old}" "${new}"
            ;;
          pr)
            if ! bash "$0" _pr_one "${name}" "${old}" "${new}" "${base}" < /dev/null; then
              printf 'autobump: %s %s failed\n' "${name}" "${new}" >&2
              failures=$((failures + 1))
              git switch --discard-changes "${base}"
            fi
            ;;
        esac
      done < "${list}"
      [ "${failures}" -eq 0 ]
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
