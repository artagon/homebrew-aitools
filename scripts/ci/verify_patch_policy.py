#!/usr/bin/env python3
"""Deterministic README marker updater and publish.yml staged-patch policy validator."""

from pathlib import Path
import re
import subprocess
import sys

BEGIN_MARKER = "<!-- BEGIN BOTTLE_PROVENANCE_TABLE -->"
END_MARKER = "<!-- END BOTTLE_PROVENANCE_TABLE -->"

BOTTLE_BLOCK_RE = re.compile(r"(?m)^  bottle do\n(.*?)^  end\n", re.S)
BOTTLE_STMT_RE = re.compile(
    r"^(?:"
    r'    root_url "https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/releases/download/[A-Za-z0-9@.%_+-]+"|'
    r"    rebuild [0-9]+|"
    r'    sha256 (?:cellar: (?::any|:any_skip_relocation|"[^"]+"), )?[a-z0-9_]+: "[0-9a-f]{64}"'
    r")$"
)


def strip_readme_table(doc: str) -> str:
    b_idx = doc.find(BEGIN_MARKER)
    e_idx = doc.find(END_MARKER)
    if b_idx < 0 or e_idx < 0 or e_idx < b_idx:
        raise ValueError("Missing or misordered BOTTLE_PROVENANCE_TABLE markers")
    if doc.count(BEGIN_MARKER) != 1 or doc.count(END_MARKER) != 1:
        raise ValueError("Duplicate BOTTLE_PROVENANCE_TABLE markers")
    return doc[:b_idx] + doc[e_idx + len(END_MARKER) :]


def cmd_replace_readme(readme_path: Path, out_path: Path, block_path: Path) -> int:
    text = readme_path.read_text(encoding="utf-8")
    replacement = block_path.read_text(encoding="utf-8").rstrip("\n")
    _ = strip_readme_table(text)
    b_idx = text.find(BEGIN_MARKER)
    e_idx = text.find(END_MARKER)
    updated = text[:b_idx] + replacement + text[e_idx + len(END_MARKER) :]
    out_path.write_text(updated, encoding="utf-8")
    return 0


def cmd_verify_readme_git(head_sha: str) -> int:
    before = subprocess.check_output(["git", "show", f"{head_sha}:README.md"], text=True)
    after = subprocess.check_output(["git", "show", "HEAD:README.md"], text=True)
    try:
        if strip_readme_table(before) != strip_readme_table(after):
            return 1
    except ValueError:
        return 1
    return 0


def cmd_verify_formula_git(head_sha: str, formula_path: str) -> int:
    before = subprocess.check_output(["git", "show", f"{head_sha}:{formula_path}"], text=True)
    after = subprocess.check_output(["git", "show", f"HEAD:{formula_path}"], text=True)

    after_blocks = BOTTLE_BLOCK_RE.findall(after)
    if len(after_blocks) != 1 or len(BOTTLE_BLOCK_RE.findall(before)) > 1:
        return 1

    inner_lines = [ln for ln in after_blocks[0].splitlines() if ln != ""]
    if not inner_lines or not all(BOTTLE_STMT_RE.match(ln) for ln in inner_lines):
        return 1

    def strip_bottle(text: str) -> str:
        stripped = BOTTLE_BLOCK_RE.sub("", text, count=1)
        return re.sub(r"\n{3,}", "\n\n", stripped)

    if strip_bottle(before) != strip_bottle(after):
        return 1
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: verify_patch_policy.py <replace-readme|verify-readme-git|verify-formula-git> ...\n")
        return 2
    mode = sys.argv[1]
    if mode == "replace-readme" and len(sys.argv) == 5:
        try:
            return cmd_replace_readme(Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4]))
        except (OSError, ValueError) as exc:
            sys.stderr.write(f"{exc}\n")
            return 1
    if mode == "verify-readme-git" and len(sys.argv) == 3:
        return cmd_verify_readme_git(sys.argv[2])
    if mode == "verify-formula-git" and len(sys.argv) == 4:
        return cmd_verify_formula_git(sys.argv[2], sys.argv[3])
    sys.stderr.write(f"Invalid invocation: {sys.argv[1:]}\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
