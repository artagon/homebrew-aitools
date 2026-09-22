#!/usr/bin/env python3
"""Run real installer integrations; see tests/README.md. No live agent state is used."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


INSTALLER_SHA256 = "3fe291e647cf7f779aa164f638e3033bb69ffe3c969e21740d708517a5d79b9f"
TARGETS = {
    "claude": ".claude/skills", "codex": ".agents/skills",
    "agy": ".gemini/antigravity-cli/skills", "kimi": ".kimi-code/skills",
    "grok": ".grok/skills", "copilot": ".copilot/skills", "shared": ".agents/skills",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Suite:
    def __init__(self, args):
        self.repo = Path(__file__).resolve().parents[1]
        self.scratch = Path(tempfile.mkdtemp(prefix="ripwire-integration-")).resolve()
        self.results = []
        self.args = args
        self.source_hashes = {str(p.relative_to(self.repo)): digest(p) for p in
                              (self.repo / "Formula/ripwire.rb", self.repo / "scripts/install-agent-skills.sh")}
        formula_snapshot = self.scratch / "ripwire.rb"
        standalone_snapshot = self.scratch / "install-agent-skills.sh"
        shutil.copyfile(self.repo / "Formula/ripwire.rb", formula_snapshot)
        shutil.copyfile(self.repo / "scripts/install-agent-skills.sh", standalone_snapshot)
        if (digest(formula_snapshot) != self.source_hashes["Formula/ripwire.rb"] or
                digest(standalone_snapshot) != self.source_hashes["scripts/install-agent-skills.sh"]):
            raise RuntimeError("Source changed while creating test snapshot; rerun")
        original = Path(args.pkgshare).resolve()
        installer = original / "skills/install.sh"
        if not installer.is_file() or digest(installer) != INSTALLER_SHA256:
            raise RuntimeError("Requires the unmodified Ripwire 0.5.0 bundled installer")
        self.payload = self.scratch / "payload"
        shutil.copytree(original, self.payload, symlinks=False)
        self.expected = {}
        for contributor in (False, True):
            self.expected[contributor] = {
                p.parent.name for p in (self.payload / "skills").glob("ripwire-*/SKILL.md")
                if contributor or not re.search(r"^audience: contributor$", p.read_text(), re.M)
            }
        if len(self.expected[False]) != 16 or len(self.expected[True]) != 17:
            raise RuntimeError("Unexpected pinned payload skill set")
        # Ruby evaluates the precise formula heredoc, including interpolation and escaping.
        # This does not reimplement or translate shell text.
        ruby = shutil.which("ruby")
        if not ruby:
            raise RuntimeError("Ruby is required to evaluate the formula wrapper")
        expr = r'''source = File.read(ARGV[0])
match = source.match(/\(bin\/"ripwire-agent-install"\)\.write (<<~SHELL\n.*?^    SHELL\n)/m)
abort "Cannot locate formula wrapper heredoc" unless match
opt_pkgshare = ARGV[1]
print eval(match[1], binding, ARGV[0])
'''
        generated = subprocess.run([ruby, "-e", expr, str(formula_snapshot),
                                    str(self.payload)], capture_output=True, text=True, check=True)
        wrapper = self.scratch / "ripwire-agent-install"
        wrapper.write_text(generated.stdout)
        self.entrypoints = {"formula": wrapper, "standalone": standalone_snapshot}
        self.shells = {"bash32": Path(args.bash32), "modern": Path(args.modern_bash)}
        for name, shell in self.shells.items():
            version = subprocess.run([str(shell), "--version"], capture_output=True, text=True, check=True).stdout
            if name == "bash32" and not re.search(r"version 3\.2\.", version):
                raise RuntimeError("--bash32 must identify Bash 3.2")
            if name == "modern" and not re.search(r"version [5-9]\.", version):
                raise RuntimeError("--modern-bash must identify Bash 5 or newer")
        self.commands = {}
        for command in ("basename", "dirname", "mkdir", "grep", "rm", "ln", "mktemp", "mv", "chmod", "cat", "jq"):
            resolved = shutil.which(command)
            if not resolved:
                raise RuntimeError("Required command missing: " + command)
            self.commands[command] = resolved

    def environment(self, shell, name):
        root = self.scratch / name
        home = root / "home"
        bindir = root / "bin"
        home.mkdir(parents=True)
        bindir.mkdir()
        (root / "tmp").mkdir()
        for command, resolved in self.commands.items():
            (bindir / command).symlink_to(resolved)
        (bindir / "bash").symlink_to(shell)
        return home, {"HOME": str(home), "PATH": str(bindir), "LC_ALL": "C",
                      "TMPDIR": str(root / "tmp"), "RIPWIRE_PKGSHARE": str(self.payload)}

    def invoke(self, entry, shell, env, flags):
        proc = subprocess.run([str(shell), str(entry), *flags], env=env,
                              cwd=env["HOME"], capture_output=True, text=True, timeout=120)
        assert proc.returncode == 0, f"exit {proc.returncode}: {proc.stderr.strip()}"
        return proc.stdout

    @staticmethod
    def tree(home):
        return {str(p.relative_to(home)): ("link", os.readlink(p)) if p.is_symlink()
                else ("file", digest(p)) if p.is_file() else ("directory", "")
                for p in home.rglob("*")}

    @staticmethod
    def no_hooks(home):
        assert not (home / ".claude/settings.json").exists(), "unexpected Claude hooks"
        assert not (home / ".codex/hooks.json").exists(), "unexpected Codex hooks"

    def skills(self, destination, contributor=False):
        manifest = destination / ".ripwire-manifest-v1"
        assert manifest.is_file(), f"missing manifest: {destination}"
        lines = manifest.read_text().splitlines()
        assert lines[0] == "version=1", "manifest version"
        actual = [line.removeprefix("skill=") for line in lines[1:]]
        assert len(actual) == len(set(actual)), "duplicate manifest skill"
        assert set(actual) == self.expected[contributor], "wrong manifest skill set"
        assert {p.name for p in destination.glob("ripwire-*")} == self.expected[contributor], "unexpected installed skill set"
        for skill in actual:
            link = destination / skill
            assert link.is_symlink(), f"not a symlink: {skill}"
            assert link.resolve() == self.payload / "skills" / skill, "wrong payload link"
            assert (link / "SKILL.md").is_file(), "broken skill link"

    def case(self, name, callback):
        try:
            callback()
            result = {"case": name, "passed": True}
        except (AssertionError, subprocess.SubprocessError, OSError) as exc:
            result = {"case": name, "passed": False, "error": str(exc)}
        self.results.append(result)
        print(("PASS " if result["passed"] else "FAIL ") + name +
              (": " + result["error"] if not result["passed"] else ""), flush=True)

    def regression(self, label, entry, shell, kind):
        home, env = self.environment(shell, label)
        if kind == "default":
            self.invoke(entry, shell, env, [])
            self.skills(home / TARGETS["shared"])
        elif kind == "custom_agy":
            custom = home / "custom agy skills"
            custom.mkdir()
            env["AGY_SKILLS_DIR"] = str(custom)
            before = self.tree(home)
            listing = self.invoke(entry, shell, env, ["--list"])
            assert re.search(r"^\s*agy\s+installed\s+", listing, re.M), "custom AGY root not detected"
            assert str(custom) in listing, "custom AGY path absent from list"
            assert self.tree(home) == before, "--list changed agent state"
            self.invoke(entry, shell, env, [])
            self.skills(custom)
            self.invoke(entry, shell, env, ["--all", "--contributor"])
            self.skills(custom, True)
            assert not (home / ".gemini").exists(), "custom AGY root ignored"
            self.no_hooks(home)
        elif kind == "shared_hook":
            (home / ".agents").mkdir()
            self.invoke(entry, shell, env, ["--hook"])
            assert not (home / ".codex").exists(), "shared root falsely created Codex configuration"
            assert not (home / ".claude").exists(), "shared root falsely created Claude configuration"
            self.skills(home / TARGETS["shared"])

    def install_matrix(self, name, entry, shell, target, contributor):
        home, env = self.environment(shell, name)
        flags = [] if target == "default" else ["--" + target]
        if target == "all":
            for root in (".claude", ".codex", ".gemini", ".kimi-code", ".grok", ".copilot"):
                (home / root).mkdir()
            selected = set(TARGETS.values())
        else:
            selected = {TARGETS["shared" if target == "default" else target]}
        if contributor:
            flags.append("--contributor")
        self.invoke(entry, shell, env, flags)
        for destination in selected:
            self.skills(home / destination, contributor)
        for destination in set(TARGETS.values()) - selected:
            assert not (home / destination).exists(), "unselected target received skills"
        self.no_hooks(home)
        # Compare file contents and links, not mtimes: installer intentionally refreshes links.
        before = self.tree(home)
        self.invoke(entry, shell, env, flags)
        assert self.tree(home) == before, "repeat install changed installed state"
        if contributor:
            self.invoke(entry, shell, env, [f for f in flags if f != "--contributor"])
            for destination in selected:
                self.skills(home / destination, False)

    def hook_install(self, name, entry, shell, target, contributor):
        home, env = self.environment(shell, name)
        config = home / (".claude/settings.json" if target == "claude" else ".codex/hooks.json")
        config.parent.mkdir()
        config.write_text(json.dumps({"existing_setting": "preserve-me", "hooks": {
            "PreToolUse": [{"matcher": "other", "hooks": [{"type": "command", "command": "echo preserved"}]}]}}))
        flags = ["--" + target, "--hook"] + (["--contributor"] if contributor else [])
        self.invoke(entry, shell, env, flags)
        self.skills(home / TARGETS[target], contributor)
        contents = json.loads(config.read_text())
        assert contents["existing_setting"] == "preserve-me", "unrelated setting overwritten"
        for event in ("PreToolUse", "SessionStart", "UserPromptSubmit"):
            hooks = [hook for entry in contents["hooks"][event] for hook in entry["hooks"]]
            ours = [h for h in hooks if str(self.payload / "hooks") in h["command"]]
            assert len(ours) == 1, f"missing or duplicate {event} hook"
        assert contents["hooks"]["PreToolUse"][0]["hooks"][0]["command"] == "echo preserved"
        opposite = home / (".codex/hooks.json" if target == "claude" else ".claude/settings.json")
        assert not opposite.exists(), "hook registered for unselected agent"
        before = self.tree(home)
        self.invoke(entry, shell, env, flags)
        assert self.tree(home) == before, "repeat hook install changed or duplicated configuration"

    def cli_contract(self, name, entry, shell):
        home, env = self.environment(shell, name)
        before = self.tree(home)
        help_text = self.invoke(entry, shell, env, ["--help"])
        for target in TARGETS:
            assert "--" + target in help_text, "target missing from help"
        listing = self.invoke(entry, shell, env, ["--list"])
        for target in TARGETS.keys() - {"shared"}:
            assert re.search(r"^\s*" + target + r"\s+not found\s+", listing, re.M), "non-isolated agent detection"
        invalid = subprocess.run([str(shell), str(entry), "--invalid-integration-flag"],
                                 env=env, cwd=home, capture_output=True, text=True, timeout=30)
        assert invalid.returncode == 2, "unknown option did not exit 2"
        assert "Unknown option" in invalid.stderr, "missing unknown option diagnostic"
        assert self.tree(home) == before, "non-installing CLI action changed agent state"

    def run(self):
        for entryname, entry in self.entrypoints.items():
            for shellname, shell in self.shells.items():
                for kind in ("default", "custom_agy", "shared_hook"):
                    name = f"{entryname}-{shellname}-{kind}"
                    self.case(name, lambda n=name, e=entry, s=shell, k=kind:
                              self.regression(n, e, s, k))
                if self.args.regressions_only:
                    continue
                for target in ("default", "all", *TARGETS):
                    for contributor in (False, True):
                        name = f"{entryname}-{shellname}-{target}-contributor{int(contributor)}"
                        self.case(name, lambda n=name, e=entry, s=shell, t=target, c=contributor:
                                  self.install_matrix(n, e, s, t, c))
                for target in ("claude", "codex"):
                    for contributor in (False, True):
                        name = f"{entryname}-{shellname}-{target}-hook-contributor{int(contributor)}"
                        self.case(name, lambda n=name, e=entry, s=shell, t=target, c=contributor:
                                  self.hook_install(n, e, s, t, c))
                name = f"{entryname}-{shellname}-cli-contract"
                self.case(name, lambda n=name, e=entry, s=shell: self.cli_contract(n, e, s))
        return self.results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pkgshare", default="/opt/homebrew/opt/ripwire/share/ripwire")
    parser.add_argument("--bash32", default="/bin/bash")
    parser.add_argument("--modern-bash", default="/opt/homebrew/bin/bash")
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--regressions-only", action="store_true")
    args = parser.parse_args()
    try:
        suite = Suite(args)
        results = suite.run()
        report = {"scratch": str(suite.scratch), "installer_sha256": INSTALLER_SHA256,
                  "source_sha256": suite.source_hashes,
                  "results": results, "passed": sum(r["passed"] for r in results),
                  "failed": sum(not r["passed"] for r in results)}
    except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
        report = {"prerequisite_error": str(exc), "failed": 1}
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(report, indent=2) + "\n")
    print("Receipt: " + str(args.receipt))
    return int(report["failed"] > 0)


if __name__ == "__main__":
    sys.exit(main())
