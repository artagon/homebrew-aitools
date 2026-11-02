#!/usr/bin/env python3
"""Bump tap formulae that lag their upstream release; see docs/agent-context.md.

Each formula's livecheck block finds the latest release. A bump points every
url that names the current version at the new one and recomputes the sha256
that follows it, so single-url and per-platform formulae bump the same way.
A new upstream version drops any formula revision. A bump of the Java grammar
also bumps the revision of each formula that compiles the grammar in.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

TAP = "artagon/aitools"
REPO = Path(__file__).resolve().parents[1]
FORMULA_DIR = REPO / "Formula"
GRAMMAR = "tree-sitter-java-valhalla"
GRAMMAR_DEPENDENTS = ("ast-grep-valhalla", "ripwire")
URL_SHA256 = re.compile(r'url "(?P<url>[^"]+)"(?P<gap>\n[ ]*)sha256 "[0-9a-f]{64}"')
REVISION = re.compile(r"^  revision (\d+)\n", re.MULTILINE)
LICENSE = re.compile(r'^  license "[^"]*"\n', re.MULTILINE)
PR_NOTE = """Upstream released {name} {new}; the formula had {old}.

Opened by `scripts/autobump.py`, which dispatched the `brew test-bot` workflow
to build, test, and bottle {formulae}. When it passes, publish the bottles and
merge with `gh workflow run publish.yml -f pull_request=<this PR number>`. Do not
merge this pull request directly: the formula would ship without bottles.

A Ripwire bump fails the installer integration suite on purpose when the
bundled installer or skill set changes: review the payload, then update the
pins in `tests/integration_agent_install.py`.
"""


def run(args, capture=False):
    result = subprocess.run(args, cwd=REPO, check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout if capture else ""


def sha256_of(url):
    request = urllib.request.Request(url, headers={"User-Agent": "artagon-aitools-autobump"})
    digest = hashlib.sha256()
    with urllib.request.urlopen(request, timeout=300) as response:
        for chunk in iter(lambda: response.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def bump_text(text, old, new, fetch=sha256_of):
    """Return text with every url naming `old` moved to `new` and its sha256 refreshed."""
    changed = 0

    def replace(match):
        nonlocal changed
        url = match.group("url")
        if old not in url:
            return match.group(0)
        changed += 1
        new_url = url.replace(old, new)
        return 'url "{}"{}sha256 "{}"'.format(new_url, match.group("gap"), fetch(new_url))

    text = URL_SHA256.sub(replace, text)
    if not changed:
        raise RuntimeError("no url names version " + old)
    return REVISION.sub("", text, count=1)


def bump_revision(text):
    """Return text with its revision incremented, adding `revision 1` after `license`."""
    match = REVISION.search(text)
    if match:
        bumped = "  revision {}\n".format(int(match.group(1)) + 1)
        return text[:match.start()] + bumped + text[match.end():]
    license_line = LICENSE.search(text)
    if not license_line:
        raise RuntimeError("no license line to place a revision after")
    return text[:license_line.end()] + "  revision 1\n" + text[license_line.end():]


def outdated(formulae):
    """Return (name, current, latest) for each formula with a newer upstream release."""
    args = ["brew", "livecheck", "--formula", "--json", "--quiet", "--newer-only"]
    args += [TAP + "/" + name for name in formulae] if formulae else ["--tap", TAP]
    bumps = []
    for item in json.loads(run(args, capture=True) or "[]"):
        version = item.get("version") or {}
        if item.get("status") == "error":
            print("livecheck error: " + json.dumps(item), file=sys.stderr)
        elif version.get("outdated"):
            bumps.append((item["formula"].split("/")[-1], version["current"], version["latest"]))
    return bumps


def affected(name):
    """Return the formulae a bump of `name` changes: the formula, and its dependents for the grammar."""
    return [name, *GRAMMAR_DEPENDENTS] if name == GRAMMAR else [name]


def apply_bump(name, old, new):
    """Write the bump for `name` into the working tree and return the changed paths."""
    path = FORMULA_DIR / (name + ".rb")
    path.write_text(bump_text(path.read_text(), old, new))
    changed = [path]
    for dependent in affected(name)[1:]:
        dependent_path = FORMULA_DIR / (dependent + ".rb")
        dependent_path.write_text(bump_revision(dependent_path.read_text()))
        changed.append(dependent_path)
    return changed


def open_pull_request(name, old, new, base):
    branch = "bump/{}-{}".format(name, new)
    if run(["git", "ls-remote", "--heads", "origin", branch], capture=True).strip():
        print("{}: branch {} already exists".format(name, branch))
        return
    run(["git", "switch", "--create", branch, "origin/" + base])
    paths = [str(path) for path in apply_bump(name, old, new)]
    run(["brew", "style", *paths])
    run(["git", "add", "--", *paths])
    run(["git", "commit", "--message", "{} {}".format(name, new)])
    run(["git", "push", "origin", branch])
    formulae = " ".join(TAP + "/" + formula for formula in affected(name))
    note = PR_NOTE.format(name=name, old=old, new=new, formulae=formulae)
    run(["gh", "pr", "create", "--base", base, "--head", branch, "--title", "{} {}".format(name, new),
         "--body", note])
    # Events from GITHUB_TOKEN start no pull_request run; a dispatch is allowed, and
    # brew pr-pull finds its bottles through the check suite on the branch head.
    run(["gh", "workflow", "run", "tests.yml", "--ref", branch, "-f", "formulae=" + formulae])
    run(["git", "switch", base])


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    for command, text in (("check", "list formulae that lag their upstream release"),
                          ("write", "write the bumps into the working tree, without Git"),
                          ("pr", "open one pull request per bump (CI)")):
        sub = commands.add_parser(command, help=text)
        sub.add_argument("formula", nargs="*", help="formula names (default: the whole tap)")
        if command == "pr":
            sub.add_argument("--base", default="main", help="branch to bump (default: main)")
    rewrite = commands.add_parser("rewrite", help="print FILE bumped from OLD to NEW")
    rewrite.add_argument("file")
    rewrite.add_argument("old")
    rewrite.add_argument("new")
    args = parser.parse_args()

    if args.command == "rewrite":
        sys.stdout.write(bump_text(Path(args.file).read_text(), args.old, args.new))
        return 0
    bumps = outdated(args.formula)
    for name, old, new in bumps:
        print("{}: {} -> {}".format(name, old, new))
    if args.command == "write":
        for name, old, new in bumps:
            apply_bump(name, old, new)
    elif args.command == "pr":
        failures = []
        for name, old, new in bumps:
            try:
                open_pull_request(name, old, new, args.base)
            except (subprocess.CalledProcessError, RuntimeError, OSError) as error:
                failures.append("{}: {}".format(name, error))
                run(["git", "switch", "--discard-changes", args.base])
        for failure in failures:
            print(failure, file=sys.stderr)
        return 1 if failures else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
