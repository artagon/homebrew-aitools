#!/usr/bin/env python3
"""Unit and integration tests for scripts/verify-provenance.sh across Bash 3.2 and Bash 5+."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile


CERT_IDENTITY = (
    "https://github.com/artagon/homebrew-aitools/"
    ".github/workflows/sign-bottles.yml@refs/heads/main"
)
LINEAGE_TYPE = "https://github.com/artagon/homebrew-aitools/bottle-lineage/v1"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_executable(path: Path, content: str) -> None:
    if content.startswith("#!/usr/bin/env python3\n"):
        real_py = Path(getattr(sys, "_base_executable", sys.executable)).resolve()
        content = f"#!{real_py} -B -S\n" + content[len("#!/usr/bin/env python3\n") :]
    path.write_text(content, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def reference_parse_formula(rb_path: Path, tag: str = "arm64_tahoe") -> dict:
    """Independent Python parser used to cross-check Bash parse_formula_metadata."""
    formula = rb_path.stem
    lines = rb_path.read_text(encoding="utf-8").splitlines()
    in_livecheck = False
    lc_indent = ""
    in_resource = False
    res_indent = ""
    in_bottle = False
    bot_indent = ""

    explicit_version = ""
    revision = 0
    primary_url = ""
    root_url = ""
    rebuild = 0
    bottle_sha = ""

    for line in lines:
        if re.match(r"^  (def (install|caveats|post_install)|test do)$|^__END__$", line):
            break
        if in_livecheck:
            if line == f"{lc_indent}end":
                in_livecheck = False
            continue
        if in_resource:
            if line == f"{res_indent}end":
                in_resource = False
            continue
        if in_bottle:
            if line == f"{bot_indent}end":
                in_bottle = False
                continue
            m_root = re.match(r'^\s*root_url "([^"]+)"$', line)
            m_reb = re.match(r"^\s*rebuild (\d+)$", line)
            m_sha = re.search(rf'\b{re.escape(tag)}:\s*"([0-9a-f]{{64}})"', line)
            if m_root:
                root_url = m_root.group(1)
            elif m_reb:
                rebuild = int(m_reb.group(1))
            elif line.lstrip().startswith("sha256 ") and m_sha:
                bottle_sha = m_sha.group(1)
            continue

        m_lc = re.match(r"^(\s*)livecheck do$", line)
        if m_lc:
            in_livecheck = True
            lc_indent = m_lc.group(1)
            continue
        m_res = re.match(r'^(\s*)resource "[^"]+" do$', line)
        if m_res:
            in_resource = True
            res_indent = m_res.group(1)
            continue
        m_bot = re.match(r"^(\s*)bottle do$", line)
        if m_bot:
            in_bottle = True
            bot_indent = m_bot.group(1)
            continue

        m_ver = re.match(r'^  version "([^"]+)"$', line)
        m_rev = re.match(r"^  revision (\d+)$", line)
        m_url = re.match(r'^\s*url "([^"]+)"$', line)
        if m_ver:
            explicit_version = m_ver.group(1)
        elif m_rev:
            revision = int(m_rev.group(1))
        elif not primary_url and m_url:
            primary_url = m_url.group(1)

    if explicit_version:
        version = explicit_version
    else:
        m_dl = re.search(r"releases/download/([^/]+)/", primary_url)
        m_ar = re.search(
            r"archive/(?:refs/tags/)?([^/]+)\.(?:tar\.gz|tar\.xz|tgz|zip)$",
            primary_url,
        )
        raw_tag = m_dl.group(1) if m_dl else (m_ar.group(1) if m_ar else "")
        if raw_tag.startswith(f"{formula}-"):
            raw_tag = raw_tag[len(formula) + 1 :]
        if re.match(r"^[vV][0-9]", raw_tag):
            raw_tag = raw_tag[1:]
        version = raw_tag

    pkg_version = f"{version}_{revision}" if revision > 0 else version
    reb_suffix = f".{rebuild}" if rebuild > 0 else ""
    ext = f".{tag}.bottle{reb_suffix}.tar.gz"
    brew_fn = f"{formula}--{pkg_version}{ext}"
    raw_rel = f"{formula}-{pkg_version}{ext}"
    rel_fn = raw_rel.replace("@", "%40").replace("+", "%2B")
    return {
        "formula": formula,
        "version": version,
        "pkg_version": pkg_version,
        "release_tag": f"{formula}-{pkg_version}",
        "root_url": root_url,
        "brew_filename": brew_fn,
        "release_filename": rel_fn,
        "expected_sha256": bottle_sha,
    }


def make_spdx_doc(name: str, version: str, extra_pkg: str = "core-bin") -> dict:
    return {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": name,
        "documentNamespace": f"https://anchore.com/syft/file/{name}",
        "packages": [
            {"name": name, "SPDXID": "SPDXRef-Root", "versionInfo": version},
            {"name": extra_pkg, "SPDXID": "SPDXRef-Pkg-1", "versionInfo": version},
        ],
    }


def make_cdx_doc(name: str, version: str) -> dict:
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "metadata": {"component": {"name": name, "version": version}},
        "components": [{"type": "library", "name": "dep-a", "version": "1.0.0"}],
    }


def make_spdx_sigstore_bundle(spdx_doc: dict) -> dict:
    statement = {
        "_type": "https://in-toto.io/Statement/v1",
        "predicateType": "https://spdx.dev/Document",
        "predicate": spdx_doc,
    }
    payload_b64 = base64.b64encode(
        json.dumps(statement, separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    return {
        "mediaType": "application/vnd.dev.sigstore.bundle.v0.3+json",
        "dsseEnvelope": {
            "payloadType": "application/vnd.in-toto+json",
            "payload": payload_b64,
            "signatures": [{"sig": "dGVzdA=="}],
        },
    }


TRUSTED_ROOT_JSONL = "\n".join(
    [
        json.dumps(
            {
                "mediaType": "application/vnd.dev.sigstore.trustedroot+json;version=0.1",
                "certificateAuthorities": [{"uri": "https://fulcio.sigstore.dev"}],
            }
        ),
        json.dumps(
            {
                "mediaType": "application/vnd.dev.sigstore.trustedroot+json;version=0.1",
                "certificateAuthorities": [{"uri": "https://fulcio.githubapp.com"}],
            }
        ),
    ]
) + "\n"


GH_SHIM = r'''#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import sys

state = json.loads(Path(os.environ["MOCK_PROVENANCE_STATE"]).read_text(encoding="utf-8"))
log_path = Path(os.environ["MOCK_CALL_LOG"])
args = sys.argv[1:]
with log_path.open("a", encoding="utf-8") as fh:
    fh.write(json.dumps({"tool": "gh", "args": args}) + "\n")

if args == ["attestation", "trusted-root"]:
    sys.stdout.write(state["trusted_root_jsonl"])
    sys.exit(0)

if len(args) >= 3 and args[0] == "attestation" and args[1] == "verify":
    artifact = Path(args[2])
    if not artifact.is_file():
        sys.stderr.write("missing artifact\n")
        sys.exit(1)
    sha = hashlib.sha256(artifact.read_bytes()).hexdigest()

    def opt(flag):
        if flag in args:
            idx = args.index(flag)
            return args[idx + 1]
        return None

    assert opt("--repo") == "artagon/homebrew-aitools", f"bad --repo: {args}"
    assert opt("--cert-identity") == state["expected_cert_identity"], f"bad --cert-identity: {args}"
    assert opt("--source-ref") == "refs/heads/main", f"bad --source-ref: {args}"
    assert "--deny-self-hosted-runners" in args, "missing --deny-self-hosted-runners"
    assert opt("--format") == "json", "missing --format json"

    if state.get("expect_bundle"):
        bpath = opt("--bundle")
        assert bpath and Path(bpath).is_file(), f"missing --bundle file: {bpath}"
    if state.get("expect_custom_trusted_root"):
        trpath = opt("--custom-trusted-root")
        assert trpath and Path(trpath).is_file(), f"missing --custom-trusted-root: {trpath}"

    pred_type = opt("--predicate-type") or "https://slsa.dev/provenance/v1"
    entry = state["by_sha"].get(sha)
    if not entry:
        sys.stderr.write(f"no attestation for {sha}\n")
        sys.exit(1)

    san = state.get("override_san", state["expected_cert_identity"])
    mode = state.get("subject_mode", "dual")

    if pred_type == "https://slsa.dev/provenance/v1":
        if mode == "missing_double_dash":
            subjects = [{"name": entry["release_filename"], "digest": {"sha256": sha}}]
            out = [
                {
                    "verificationResult": {
                        "signature": {"certificate": {"subjectAlternativeName": san}},
                        "statement": {
                            "predicateType": pred_type,
                            "subject": subjects,
                        },
                    }
                }
            ]
        elif mode == "split_subjects":
            out = [
                {
                    "verificationResult": {
                        "signature": {"certificate": {"subjectAlternativeName": san}},
                        "statement": {
                            "predicateType": pred_type,
                            "subject": [{"name": entry["brew_filename"], "digest": {"sha256": sha}}],
                        },
                    }
                },
                {
                    "verificationResult": {
                        "signature": {"certificate": {"subjectAlternativeName": san}},
                        "statement": {
                            "predicateType": pred_type,
                            "subject": [{"name": entry["release_filename"], "digest": {"sha256": sha}}],
                        },
                    }
                },
            ]
        else:
            subjects = [
                {"name": entry["brew_filename"], "digest": {"sha256": sha}},
                {"name": entry["release_filename"], "digest": {"sha256": sha}},
            ]
            out = [
                {
                    "verificationResult": {
                        "signature": {"certificate": {"subjectAlternativeName": san}},
                        "statement": {
                            "predicateType": pred_type,
                            "subject": subjects,
                        },
                    }
                }
            ]
        sys.stdout.write(json.dumps(out))
        sys.exit(0)

    if pred_type == state["lineage_type"]:
        subjects = [
            {"name": entry["brew_filename"], "digest": {"sha256": sha}},
            {"name": entry["release_filename"], "digest": {"sha256": sha}},
        ]
        out = [
            {
                "verificationResult": {
                    "signature": {"certificate": {"subjectAlternativeName": san}},
                    "statement": {
                        "predicateType": pred_type,
                        "subject": subjects,
                        "predicate": {"bottles": [entry]},
                    },
                }
            }
        ]
        sys.stdout.write(json.dumps(out))
        sys.exit(0)

sys.stderr.write(f"unexpected gh invocation: {args}\n")
sys.exit(1)
'''


COSIGN_SHIM = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

state = json.loads(Path(os.environ["MOCK_PROVENANCE_STATE"]).read_text(encoding="utf-8"))
log_path = Path(os.environ["MOCK_CALL_LOG"])
args = sys.argv[1:]
tuf_root = os.environ.get("TUF_ROOT", "")
with log_path.open("a", encoding="utf-8") as fh:
    fh.write(json.dumps({"tool": "cosign", "args": args, "tuf_root": tuf_root}) + "\n")

assert "--offline" not in args, "deprecated --offline passed to cosign v3"
assert tuf_root and not tuf_root.startswith(os.environ["HOME"]), f"unsafe TUF_ROOT: {tuf_root}"

def opt(flag):
    if flag in args:
        idx = args.index(flag)
        return args[idx + 1]
    return None

assert opt("--certificate-identity") == state["expected_cert_identity"]
assert opt("--certificate-oidc-issuer") == "https://token.actions.githubusercontent.com"
bpath = opt("--bundle")
assert bpath and Path(bpath).is_file(), f"missing cosign --bundle: {bpath}"

if state.get("expect_cosign_trusted_root"):
    tr = opt("--trusted-root")
    assert tr and Path(tr).is_file(), f"missing cosign --trusted-root: {tr}"
    doc = json.loads(Path(tr).read_text(encoding="utf-8"))
    assert doc.get("mediaType") == "application/vnd.dev.sigstore.trustedroot+json;version=0.1"
    assert "sigstore.dev" in json.dumps(doc)

if args[0] == "verify-blob":
    sys.stdout.write("Verified OK\n")
    sys.exit(0)

if args[0] == "verify-blob-attestation":
    assert opt("--type") == "spdxjson"
    sys.stdout.write("Verified OK\n")
    sys.exit(0)

sys.stderr.write(f"unexpected cosign args: {args}\n")
sys.exit(1)
'''


BREW_SHIM = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

state = json.loads(Path(os.environ["MOCK_PROVENANCE_STATE"]).read_text(encoding="utf-8"))
log_path = Path(os.environ["MOCK_CALL_LOG"])
args = sys.argv[1:]
env_snapshot = {
    "USER": os.environ.get("USER", ""),
    "XDG_CONFIG_HOME": os.environ.get("XDG_CONFIG_HOME", ""),
    "GH_CONFIG_DIR": os.environ.get("GH_CONFIG_DIR", ""),
    "GH_STATE_DIR": os.environ.get("GH_STATE_DIR", ""),
    "HOMEBREW_CACHE": os.environ.get("HOMEBREW_CACHE", ""),
}
with log_path.open("a", encoding="utf-8") as fh:
    fh.write(json.dumps({"tool": "brew", "args": args, "env": env_snapshot}) + "\n")

if args == ["--repository", "artagon/aitools"]:
    tap_repo = state.get("mock_tap_repo", "")
    if tap_repo:
        sys.stdout.write(tap_repo + "\n")
        sys.exit(0)
    sys.exit(1)

home = os.environ["HOME"]
assert env_snapshot["USER"], "USER must be populated for Homebrew trust store"
assert env_snapshot["XDG_CONFIG_HOME"] and not env_snapshot["XDG_CONFIG_HOME"].startswith(home), (
    f"XDG_CONFIG_HOME leaked into HOME: {env_snapshot['XDG_CONFIG_HOME']}"
)
assert env_snapshot["GH_STATE_DIR"] and not env_snapshot["GH_STATE_DIR"].startswith(home), (
    f"GH_STATE_DIR leaked into HOME: {env_snapshot['GH_STATE_DIR']}"
)
if state.get("expect_gh_config_dir"):
    assert env_snapshot["GH_CONFIG_DIR"] == state["expect_gh_config_dir"], (
        f"GH_CONFIG_DIR not preserved: {env_snapshot['GH_CONFIG_DIR']}"
    )

trust_marker = Path(env_snapshot["XDG_CONFIG_HOME"]) / "homebrew-trusted.json"
if args == ["trust", "--tap", "artagon/aitools"]:
    trust_marker.parent.mkdir(parents=True, exist_ok=True)
    trust_marker.write_text('{"trusted":["artagon/aitools"]}\n', encoding="utf-8")
    sys.exit(0)

if args and args[0] == "verify":
    assert trust_marker.is_file(), "brew verify called before brew trust"
    assert "--bottle-tag=arm64_tahoe" in args
    assert "--force" in args
    assert "--json" in args
    sys.stdout.write(json.dumps(state.get("brew_verify_response", [{"verified": True}])))
    sys.exit(state.get("brew_verify_rc", 0))

sys.stderr.write(f"unexpected brew args: {args}\n")
sys.exit(1)
'''


class Suite:
    def __init__(self, args):
        self.repo = Path(__file__).resolve().parents[1]
        self.script = self.repo / "scripts/verify-provenance.sh"
        if not self.script.is_file():
            raise RuntimeError(f"Missing verifier script: {self.script}")
        self.scratch = Path(tempfile.mkdtemp(prefix="verify-provenance-test-")).resolve()
        self.results = []
        self.args = args
        self.source_hashes = {
            "scripts/verify-provenance.sh": digest(self.script),
        }
        self.script_snapshot = self.scratch / "verify-provenance.sh"
        shutil.copyfile(self.script, self.script_snapshot)
        self.script_snapshot.chmod(0o755)
        if digest(self.script_snapshot) != self.source_hashes["scripts/verify-provenance.sh"]:
            raise RuntimeError("scripts/verify-provenance.sh changed during snapshot")

        self.shells = {"bash32": Path(args.bash32), "modern": Path(args.modern_bash)}
        for name, shell in self.shells.items():
            ver = subprocess.run(
                [str(shell), "--version"], capture_output=True, text=True, check=True
            ).stdout
            if name == "bash32" and not re.search(r"version 3\.2\.", ver):
                raise RuntimeError(f"--bash32 must identify Bash 3.2 (got: {ver.splitlines()[0]})")
            if name == "modern" and not re.search(r"version [5-9]\.", ver):
                raise RuntimeError(
                    f"--modern-bash must identify Bash 5+ (got: {ver.splitlines()[0]})"
                )

        self.commands = {}
        required_cmds = (
            "awk",
            "basename",
            "cat",
            "cmp",
            "cp",
            "curl",
            "dirname",
            "grep",
            "id",
            "jq",
            "mkdir",
            "mktemp",
            "mv",
            "rm",
            "uname",
        )
        for cmd in required_cmds:
            resolved = shutil.which(cmd)
            if not resolved:
                raise RuntimeError(f"Required command missing: {cmd}")
            self.commands[cmd] = resolved

        sha_cmd = shutil.which("shasum") or shutil.which("sha256sum")
        if not sha_cmd:
            raise RuntimeError("Required command missing: shasum or sha256sum")
        self.commands[Path(sha_cmd).name] = sha_cmd

    @staticmethod
    def tree(root: Path, *, ignore_macos_library: bool = False) -> dict:
        out = {}
        for p in root.rglob("*"):
            rel = p.relative_to(root)
            if ignore_macos_library and rel.parts and rel.parts[0] == "Library":
                continue
            out[str(rel)] = (
                ("link", os.readlink(p))
                if p.is_symlink()
                else ("file", digest(p))
                if p.is_file()
                else ("directory", "")
            )
        return out

    def assert_home_clean(self, home: Path, before: dict, context: str = "HOME") -> None:
        after = self.tree(home, ignore_macos_library=True)
        assert after == before, f"{context} modified: before={before}, after={after}"

    def environment(self, shell: Path, label: str, *, with_cosign: bool = True, with_brew: bool = False):
        root = self.scratch / label
        home = root / "home"
        bindir = root / "bin"
        tmpdir = root / "tmp"
        home.mkdir(parents=True)
        bindir.mkdir()
        tmpdir.mkdir()

        for cmd, resolved in self.commands.items():
            (bindir / cmd).symlink_to(resolved)
        (bindir / "bash").symlink_to(shell)

        make_executable(bindir / "gh", GH_SHIM)
        if with_cosign:
            make_executable(bindir / "cosign", COSIGN_SHIM)
        if with_brew:
            make_executable(bindir / "brew", BREW_SHIM)

        state_file = root / "mock-state.json"
        call_log = root / "call-log.jsonl"
        call_log.write_text("", encoding="utf-8")

        env = {
            "HOME": str(home),
            "PATH": str(bindir),
            "LC_ALL": "C",
            "TMPDIR": str(tmpdir),
            "MOCK_PROVENANCE_STATE": str(state_file),
            "MOCK_CALL_LOG": str(call_log),
        }
        return root, home, bindir, tmpdir, state_file, call_log, env

    def build_fixture_repo(self, root: Path, formula_names=None) -> tuple[Path, Path, dict]:
        repo_dir = root / "repo"
        formula_dir = repo_dir / "Formula"
        releases_dir = root / "releases"
        formula_dir.mkdir(parents=True)
        releases_dir.mkdir(parents=True)

        selected = (
            [self.repo / "Formula" / f"{n}.rb" for n in formula_names]
            if formula_names
            else [
                p
                for p in sorted((self.repo / "Formula").glob("*.rb"))
                if re.search(r"^\s*bottle do$", p.read_text(encoding="utf-8"), re.M)
            ]
        )

        by_sha = {}
        for src_rb in selected:
            ref = reference_parse_formula(src_rb)
            formula = ref["formula"]
            pkg_version = ref["pkg_version"]
            rel_tag = ref["release_tag"]
            brew_fn = ref["brew_filename"]
            rel_fn = ref["release_filename"]

            rel_dir = releases_dir / rel_tag
            rel_dir.mkdir(parents=True, exist_ok=True)

            bottle_bytes = f"mock-bottle:{formula}:{pkg_version}\n".encode("utf-8")
            bottle_file = rel_dir / rel_fn
            bottle_file.write_bytes(bottle_bytes)
            bottle_sha = digest(bottle_file)

            (rel_dir / f"{rel_fn}.sha256").write_text(
                f"{bottle_sha}  {rel_fn}\n", encoding="utf-8"
            )

            spdx_doc = make_spdx_doc(formula, pkg_version)
            cdx_doc = make_cdx_doc(formula, pkg_version)
            spdx_path = rel_dir / f"{rel_fn}.spdx.json"
            cdx_path = rel_dir / f"{rel_fn}.cdx.json"
            spdx_path.write_text(json.dumps(spdx_doc, indent=2) + "\n", encoding="utf-8")
            cdx_path.write_text(json.dumps(cdx_doc, indent=2) + "\n", encoding="utf-8")

            (rel_dir / f"{rel_fn}.intoto.jsonl").write_text(
                json.dumps({"bundle": "slsa", "sha256": bottle_sha}) + "\n", encoding="utf-8"
            )
            (rel_dir / f"{rel_fn}.lineage.intoto.jsonl").write_text(
                json.dumps({"bundle": "lineage", "sha256": bottle_sha}) + "\n", encoding="utf-8"
            )
            (rel_dir / f"{rel_fn}.sigstore.json").write_text(
                json.dumps({"mediaType": "application/vnd.dev.sigstore.bundle.v0.3+json"}) + "\n",
                encoding="utf-8",
            )
            (rel_dir / f"{rel_fn}.spdx.sigstore.json").write_text(
                json.dumps(make_spdx_sigstore_bundle(spdx_doc)) + "\n", encoding="utf-8"
            )

            file_root_url = f"file://{rel_dir}"
            rb_text = src_rb.read_text(encoding="utf-8")
            rb_text = re.sub(
                r'(^\s*root_url )"[^"]+"',
                rf'\1"{file_root_url}"',
                rb_text,
                count=1,
                flags=re.M,
            )
            rb_text = re.sub(
                r'(arm64_tahoe:\s*)"[0-9a-f]{64}"',
                rf'\1"{bottle_sha}"',
                rb_text,
                count=1,
            )
            (formula_dir / src_rb.name).write_text(rb_text, encoding="utf-8")

            by_sha[bottle_sha] = {
                "formula": formula,
                "pkg_version": pkg_version,
                "release_tag": rel_tag,
                "brew_filename": brew_fn,
                "release_filename": rel_fn,
                "bottle_sha256": bottle_sha,
                "spdx_sha256": digest(spdx_path),
                "cdx_sha256": digest(cdx_path),
            }

        state = {
            "expected_cert_identity": CERT_IDENTITY,
            "lineage_type": LINEAGE_TYPE,
            "trusted_root_jsonl": TRUSTED_ROOT_JSONL,
            "by_sha": by_sha,
        }
        return repo_dir, releases_dir, state

    def run_verifier(self, shell: Path, env: dict, flags: list[str]) -> subprocess.CompletedProcess:
        return subprocess.run(
            [str(shell), str(self.script_snapshot), *flags],
            env=env,
            cwd=env["HOME"],
            capture_output=True,
            text=True,
            timeout=300,
        )

    def case(self, name: str, callback) -> None:
        try:
            callback()
            result = {"case": name, "passed": True}
        except (AssertionError, subprocess.SubprocessError, OSError, json.JSONDecodeError) as exc:
            result = {"case": name, "passed": False, "error": str(exc)}
        self.results.append(result)
        prefix = "PASS " if result["passed"] else "FAIL "
        suffix = f": {result['error']}" if not result["passed"] else ""
        print(f"{prefix}{name}{suffix}", flush=True)

    # ── Test Cases ───────────────────────────────────────────────────────────

    def test_parse_all_17_live_formulae(self, shell: Path, label: str) -> None:
        _, home, _, _, _, _, env = self.environment(shell, label)
        env["PROVENANCE_REPO_ROOT"] = str(self.repo)
        before = self.tree(home, ignore_macos_library=True)
        proc = self.run_verifier(shell, env, ["--parse-only", "--json"])
        assert proc.returncode == 0, f"exit {proc.returncode}: {proc.stderr}"
        assert proc.stderr == "", f"unexpected stderr in --json mode: {proc.stderr}"
        doc = json.loads(proc.stdout)
        live_files = [
            p
            for p in sorted((self.repo / "Formula").glob("*.rb"))
            if re.search(r"^\s*bottle do$", p.read_text(encoding="utf-8"), re.M)
        ]
        expected_count = len(live_files)
        assert expected_count >= 17
        assert doc["ok"] is True
        assert (
            doc["checked"] == expected_count
            and doc["passed"] == expected_count
            and doc["failed"] == 0
        )

        by_name = {r["formula"]: r for r in doc["results"]}
        for rb in live_files:
            expected = reference_parse_formula(rb)
            got = by_name[expected["formula"]]
            for key in (
                "version",
                "pkg_version",
                "release_tag",
                "root_url",
                "brew_filename",
                "release_filename",
                "expected_sha256",
            ):
                assert got[key] == expected[key], (
                    f"{rb.name} {key}: got {got[key]!r}, expected {expected[key]!r}"
                )
        self.assert_home_clean(home, before)

    def test_full_verify_all_17_fixtures(self, shell: Path, label: str) -> None:
        root, home, _, _, state_file, _, env = self.environment(shell, label)
        repo_dir, _, state = self.build_fixture_repo(root)
        expected_count = len(state["by_sha"])
        assert expected_count >= 17
        state_file.write_text(json.dumps(state), encoding="utf-8")
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)
        before = self.tree(home, ignore_macos_library=True)

        proc = self.run_verifier(
            shell, env, ["--all", "--allow-file-root-url", "--require-cosign", "--json"]
        )
        assert proc.returncode == 0, f"exit {proc.returncode}: {proc.stdout}\n{proc.stderr}"
        assert proc.stderr == "", f"unexpected stderr: {proc.stderr}"
        doc = json.loads(proc.stdout)
        assert doc["ok"] is True and doc["passed"] == expected_count and doc["failed"] == 0
        for item in doc["results"]:
            assert item["spdx_packages"] == 2
            assert item["cyclonedx_components"] == 1
            for check_key in (
                "formula_metadata",
                "bottle_sha256",
                "sha256_sidecar",
                "slsa_attestation",
                "lineage_attestation",
                "cosign_blob",
                "cosign_spdx",
                "spdx_sbom",
                "cyclonedx_sbom",
            ):
                assert item["checks"][check_key] == "passed", f"{item['formula']} {check_key}"
        self.assert_home_clean(home, before)

    def test_revision_rebuild_at_and_plus_encoding(self, shell: Path, label: str) -> None:
        root, home, _, _, state_file, _, env = self.environment(shell, label)
        repo_dir = root / "repo"
        (repo_dir / "Formula").mkdir(parents=True)
        releases_dir = root / "releases"

        formula = "tool@1"
        pkg_version = "1.2.3+meta_2"
        rel_tag = f"{formula}-{pkg_version}"
        brew_fn = "tool@1--1.2.3+meta_2.arm64_tahoe.bottle.3.tar.gz"
        rel_fn = "tool%401-1.2.3%2Bmeta_2.arm64_tahoe.bottle.3.tar.gz"
        # curl URL-decodes %40 -> @ and %2B -> + when opening file:// paths.
        disk_fn = "tool@1-1.2.3+meta_2.arm64_tahoe.bottle.3.tar.gz"

        rel_dir = releases_dir / rel_tag
        rel_dir.mkdir(parents=True)
        bottle_path = rel_dir / disk_fn
        bottle_path.write_bytes(b"encoded-bottle-payload\n")
        bottle_sha = digest(bottle_path)
        (rel_dir / f"{disk_fn}.sha256").write_text(f"{bottle_sha}  {rel_fn}\n", encoding="utf-8")

        spdx_doc = make_spdx_doc(formula, pkg_version)
        cdx_doc = make_cdx_doc(formula, pkg_version)
        spdx_path = rel_dir / f"{disk_fn}.spdx.json"
        cdx_path = rel_dir / f"{disk_fn}.cdx.json"
        spdx_path.write_text(json.dumps(spdx_doc), encoding="utf-8")
        cdx_path.write_text(json.dumps(cdx_doc), encoding="utf-8")
        (rel_dir / f"{disk_fn}.sigstore.json").write_text("{}", encoding="utf-8")
        (rel_dir / f"{disk_fn}.spdx.sigstore.json").write_text(
            json.dumps(make_spdx_sigstore_bundle(spdx_doc)), encoding="utf-8"
        )

        (repo_dir / "Formula" / f"{formula}.rb").write_text(
            f'''class ToolAT1 < Formula
  desc "Synthetic formula"
  homepage "https://example.com"
  url "https://github.com/example/tool/archive/refs/tags/v1.2.3+meta.tar.gz"
  sha256 "{bottle_sha}"
  license "MIT"
  revision 2

  bottle do
    root_url "file://{rel_dir}"
    rebuild 3
    sha256 cellar: :any, arm64_tahoe: "{bottle_sha}"
  end

  def install
    bin.install "tool"
  end
end
''',
            encoding="utf-8",
        )

        state = {
            "expected_cert_identity": CERT_IDENTITY,
            "lineage_type": LINEAGE_TYPE,
            "trusted_root_jsonl": TRUSTED_ROOT_JSONL,
            "by_sha": {
                bottle_sha: {
                    "formula": formula,
                    "pkg_version": pkg_version,
                    "release_tag": rel_tag,
                    "brew_filename": brew_fn,
                    "release_filename": rel_fn,
                    "bottle_sha256": bottle_sha,
                    "spdx_sha256": digest(spdx_path),
                    "cdx_sha256": digest(cdx_path),
                }
            },
        }
        state_file.write_text(json.dumps(state), encoding="utf-8")
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)
        before = self.tree(home, ignore_macos_library=True)

        proc = self.run_verifier(
            shell, env, ["--allow-file-root-url", "--require-cosign", "--json", formula]
        )
        assert proc.returncode == 0, f"exit {proc.returncode}: {proc.stdout}\n{proc.stderr}"
        res = json.loads(proc.stdout)["results"][0]
        assert res["pkg_version"] == pkg_version
        assert res["brew_filename"] == brew_fn
        assert res["release_filename"] == rel_fn
        self.assert_home_clean(home, before)

    def test_explicit_version_stanza(self, shell: Path, label: str) -> None:
        root, _, _, _, _, _, env = self.environment(shell, label)
        repo_dir = root / "repo"
        (repo_dir / "Formula").mkdir(parents=True)
        sha = "a" * 64
        (repo_dir / "Formula/custom.rb").write_text(
            f'''class Custom < Formula
  desc "Explicit version test"
  homepage "https://example.com"
  url "https://example.com/downloads/snapshot-tarball.tar.gz"
  version "2.4.0"
  sha256 "{sha}"

  bottle do
    root_url "https://github.com/artagon/homebrew-aitools/releases/download/custom-2.4.0"
    sha256 arm64_tahoe: "{sha}"
  end

  def install
    bin.install "custom"
  end
end
''',
            encoding="utf-8",
        )
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)
        proc = self.run_verifier(shell, env, ["--parse-only", "--json", "custom"])
        assert proc.returncode == 0, proc.stdout
        res = json.loads(proc.stdout)["results"][0]
        assert res["version"] == "2.4.0"
        assert res["pkg_version"] == "2.4.0"

    def test_stale_bottle_on_version_bump(self, shell: Path, label: str) -> None:
        root, _, _, _, state_file, _, env = self.environment(shell, label)
        repo_dir, _, state = self.build_fixture_repo(root, ["ripwire"])
        state_file.write_text(json.dumps(state), encoding="utf-8")
        rb = repo_dir / "Formula/ripwire.rb"
        rb.write_text(
            rb.read_text(encoding="utf-8").replace("v0.6.9.tar.gz", "v0.7.0.tar.gz"),
            encoding="utf-8",
        )
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)

        proc = self.run_verifier(shell, env, ["--allow-file-root-url", "--json", "ripwire"])
        assert proc.returncode == 1
        doc = json.loads(proc.stdout)
        assert doc["ok"] is False and doc["failed"] == 1
        assert doc["results"][0]["checks"]["formula_metadata"] == "failed"
        assert "stale" in doc["results"][0]["error"]

    def test_save_bundles_and_offline_roundtrip(self, shell: Path, label: str) -> None:
        root, home, bindir, _, state_file, call_log, env = self.environment(shell, label)
        repo_dir, _, state = self.build_fixture_repo(root, ["ripwire"])
        state_file.write_text(json.dumps(state), encoding="utf-8")
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)

        saved_dir = root / "saved-bundles"
        proc_save = self.run_verifier(
            shell,
            env,
            [
                "--save-bundles",
                str(saved_dir),
                "--allow-file-root-url",
                "--require-cosign",
                "--json",
                "ripwire",
            ],
        )
        assert proc_save.returncode == 0, proc_save.stdout
        assert (saved_dir / "trusted_root.jsonl").is_file()

        # Remove curl completely to prove air-gapped --offline makes zero network fetches.
        (bindir / "curl").unlink()
        state["expect_bundle"] = True
        state["expect_custom_trusted_root"] = True
        state["expect_cosign_trusted_root"] = True
        state_file.write_text(json.dumps(state), encoding="utf-8")
        call_log.write_text("", encoding="utf-8")

        bundle_snapshot = self.tree(saved_dir)
        home_snapshot = self.tree(home, ignore_macos_library=True)

        proc_off = self.run_verifier(
            shell,
            env,
            [
                "--offline",
                "--bundle-dir",
                str(saved_dir),
                "--trusted-root",
                str(saved_dir / "trusted_root.jsonl"),
                "--allow-file-root-url",
                "--require-cosign",
                "--json",
                "ripwire",
            ],
        )
        assert proc_off.returncode == 0, f"{proc_off.stdout}\n{proc_off.stderr}"
        doc = json.loads(proc_off.stdout)
        assert doc["mode"] == "offline" and doc["ok"] is True
        assert self.tree(saved_dir) == bundle_snapshot, "--offline mutated --bundle-dir"
        self.assert_home_clean(home, home_snapshot, "--offline HOME")

        calls = [json.loads(line) for line in call_log.read_text(encoding="utf-8").splitlines()]
        cosign_calls = [c for c in calls if c["tool"] == "cosign"]
        assert len(cosign_calls) == 2
        for c in cosign_calls:
            assert "--offline" not in c["args"]
            assert "--trusted-root" in c["args"]

    def test_corrupted_bottle_and_sidecar(self, shell: Path, label: str) -> None:
        root, _, _, _, state_file, _, env = self.environment(shell, label)
        repo_dir, releases_dir, state = self.build_fixture_repo(root, ["ripwire"])
        state_file.write_text(json.dumps(state), encoding="utf-8")
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)

        entry = next(iter(state["by_sha"].values()))
        rel_dir = releases_dir / entry["release_tag"]
        bottle_file = rel_dir / entry["release_filename"]
        orig_bytes = bottle_file.read_bytes()

        # 1. Corrupt bottle bytes -> fails bottle_sha256 with valid JSON on stdout.
        bottle_file.write_bytes(orig_bytes + b"tamper")
        proc_bad = self.run_verifier(shell, env, ["--allow-file-root-url", "--json", "ripwire"])
        assert proc_bad.returncode == 1
        assert proc_bad.stderr == ""
        doc_bad = json.loads(proc_bad.stdout)
        assert doc_bad["ok"] is False
        assert doc_bad["results"][0]["checks"]["bottle_sha256"] == "failed"

        # 2. Restore bottle bytes, corrupt .sha256 sidecar -> fails sha256_sidecar.
        bottle_file.write_bytes(orig_bytes)
        (rel_dir / f"{entry['release_filename']}.sha256").write_text(
            "0" * 64 + f"  {entry['release_filename']}\n", encoding="utf-8"
        )
        proc_side = self.run_verifier(shell, env, ["--allow-file-root-url", "--json", "ripwire"])
        assert proc_side.returncode == 1
        doc_side = json.loads(proc_side.stdout)
        assert doc_side["results"][0]["checks"]["sha256_sidecar"] == "failed"

    def test_subject_binding_and_san_attacks(self, shell: Path, label: str) -> None:
        root, _, _, _, state_file, _, env = self.environment(shell, label)
        repo_dir, _, state = self.build_fixture_repo(root, ["ripwire"])
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)

        # 1. Missing `--` Homebrew subject fails closed.
        state["subject_mode"] = "missing_double_dash"
        state_file.write_text(json.dumps(state), encoding="utf-8")
        proc1 = self.run_verifier(shell, env, ["--allow-file-root-url", "--json", "ripwire"])
        assert proc1.returncode == 1
        assert json.loads(proc1.stdout)["results"][0]["checks"]["slsa_attestation"] == "failed"

        # 2. Split-subject array attack (two separate statements) fails closed.
        state["subject_mode"] = "split_subjects"
        state_file.write_text(json.dumps(state), encoding="utf-8")
        proc2 = self.run_verifier(shell, env, ["--allow-file-root-url", "--json", "ripwire"])
        assert proc2.returncode == 1
        assert json.loads(proc2.stdout)["results"][0]["checks"]["slsa_attestation"] == "failed"

        # 3. Wrong certificate SAN fails closed.
        state["subject_mode"] = "dual"
        state["override_san"] = (
            "https://github.com/artagon/homebrew-aitools/.github/workflows/tests.yml@refs/pull/1/merge"
        )
        state_file.write_text(json.dumps(state), encoding="utf-8")
        proc3 = self.run_verifier(shell, env, ["--allow-file-root-url", "--json", "ripwire"])
        assert proc3.returncode == 1
        assert json.loads(proc3.stdout)["results"][0]["checks"]["slsa_attestation"] == "failed"

    def test_tampered_detached_sbom_rejected(self, shell: Path, label: str) -> None:
        root, _, _, _, state_file, _, env = self.environment(shell, label)
        repo_dir, releases_dir, state = self.build_fixture_repo(root, ["ripwire"])
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)

        entry = next(iter(state["by_sha"].values()))
        rel_dir = releases_dir / entry["release_tag"]
        spdx_path = rel_dir / f"{entry['release_filename']}.spdx.json"
        tampered_spdx = make_spdx_doc("ripwire", entry["pkg_version"], extra_pkg="injected-pkg")
        spdx_path.write_text(json.dumps(tampered_spdx), encoding="utf-8")

        # 1. Caught first by signed bottle-lineage/v1 spdx_sha256 check.
        state_file.write_text(json.dumps(state), encoding="utf-8")
        proc1 = self.run_verifier(shell, env, ["--allow-file-root-url", "--json", "ripwire"])
        assert proc1.returncode == 1
        assert json.loads(proc1.stdout)["results"][0]["checks"]["lineage_attestation"] == "failed"

        # 2. Even if lineage had the tampered sha, cosign DSSE predicate comparison catches it!
        entry["spdx_sha256"] = digest(spdx_path)
        state_file.write_text(json.dumps(state), encoding="utf-8")
        proc2 = self.run_verifier(
            shell, env, ["--allow-file-root-url", "--require-cosign", "--json", "ripwire"]
        )
        assert proc2.returncode == 1
        res2 = json.loads(proc2.stdout)["results"][0]
        assert res2["checks"]["cosign_spdx"] == "failed"
        assert "DSSE predicate" in res2["error"]

    def test_cosign_absent_vs_require_cosign(self, shell: Path, label: str) -> None:
        root, _, _, _, state_file, _, env = self.environment(
            shell, label, with_cosign=False
        )
        repo_dir, _, state = self.build_fixture_repo(root, ["ripwire"])
        state_file.write_text(json.dumps(state), encoding="utf-8")
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)

        proc_ok = self.run_verifier(shell, env, ["--allow-file-root-url", "--json", "ripwire"])
        assert proc_ok.returncode == 0, proc_ok.stdout
        checks = json.loads(proc_ok.stdout)["results"][0]["checks"]
        assert checks["cosign_blob"] == "skipped"
        assert checks["cosign_spdx"] == "skipped"

        proc_req = self.run_verifier(
            shell, env, ["--allow-file-root-url", "--require-cosign", "--json", "ripwire"]
        )
        assert proc_req.returncode == 1
        assert json.loads(proc_req.stdout)["results"][0]["checks"]["cosign_blob"] == "failed"

    def test_homebrew_isolation_and_cli_hygiene(self, shell: Path, label: str) -> None:
        root, home, _, tmpdir, state_file, _, env = self.environment(
            shell, label, with_cosign=True, with_brew=True
        )
        repo_dir, _, state = self.build_fixture_repo(root, ["ripwire"])
        gh_cfg = home / ".config/gh"
        gh_cfg.mkdir(parents=True)
        (gh_cfg / "hosts.yml").write_text("github.com:\n    user: test\n", encoding="utf-8")

        state["expect_gh_config_dir"] = str(gh_cfg)
        state["mock_tap_repo"] = str(repo_dir)
        state_file.write_text(json.dumps(state), encoding="utf-8")
        env["PROVENANCE_REPO_ROOT"] = str(repo_dir)
        env.pop("USER", None)

        before_home = self.tree(home, ignore_macos_library=True)
        proc = self.run_verifier(
            shell, env, ["--homebrew", "--allow-file-root-url", "--json", "ripwire"]
        )
        assert proc.returncode == 0, f"{proc.stdout}\n{proc.stderr}"
        assert json.loads(proc.stdout)["results"][0]["checks"]["homebrew_verify"] == "passed"
        self.assert_home_clean(home, before_home, "--homebrew HOME")

        # Empty array from brew verify (e.g. bottle tag unavailable warning) must fail closed.
        state["brew_verify_response"] = []
        state_file.write_text(json.dumps(state), encoding="utf-8")
        proc_empty = self.run_verifier(
            shell, env, ["--homebrew", "--allow-file-root-url", "--json", "ripwire"]
        )
        assert proc_empty.returncode == 1
        assert json.loads(proc_empty.stdout)["results"][0]["checks"]["homebrew_verify"] == "failed"

        # Tap checkout drift vs Formula/*.rb must fail closed.
        drift_tap = root / "drift-tap"
        (drift_tap / "Formula").mkdir(parents=True)
        (drift_tap / "Formula/ripwire.rb").write_text("# drifted\n", encoding="utf-8")
        state["brew_verify_response"] = [{"verified": True}]
        state["mock_tap_repo"] = str(drift_tap)
        state_file.write_text(json.dumps(state), encoding="utf-8")
        proc_drift = self.run_verifier(
            shell, env, ["--homebrew", "--allow-file-root-url", "--json", "ripwire"]
        )
        assert proc_drift.returncode == 1
        assert "differs from checkout" in json.loads(proc_drift.stdout)["results"][0]["error"]

        # CLI usage / early-exit trap hygiene under Bash 3.2 `set -u`.
        before_tmp = set(tmpdir.iterdir())
        proc_help = self.run_verifier(shell, env, ["--help"])
        assert proc_help.returncode == 0 and "Usage:" in proc_help.stdout

        for bad_flags in (
            ["--unknown-flag"],
            ["--offline"],
            ["--offline", "--bundle-dir", str(repo_dir)],
            ["--all", "ripwire"],
            ["--file", "/nonexistent", "ripwire", "tgrep"],
        ):
            proc_bad = self.run_verifier(shell, env, bad_flags)
            assert proc_bad.returncode == 2, f"expected exit 2 for {bad_flags}, got {proc_bad.returncode}"
            assert "unbound variable" not in proc_bad.stderr
        assert set(tmpdir.iterdir()) == before_tmp, "leaked scratch directories in TMPDIR"

    def run(self) -> list[dict]:
        cases = (
            ("parse-all-17-live", self.test_parse_all_17_live_formulae),
            ("full-verify-all-17", self.test_full_verify_all_17_fixtures),
            ("revision-rebuild-encoding", self.test_revision_rebuild_at_and_plus_encoding),
            ("explicit-version-stanza", self.test_explicit_version_stanza),
            ("stale-bottle-bump", self.test_stale_bottle_on_version_bump),
            ("save-and-offline-roundtrip", self.test_save_bundles_and_offline_roundtrip),
            ("corrupted-bottle-and-sidecar", self.test_corrupted_bottle_and_sidecar),
            ("subject-binding-and-san-attacks", self.test_subject_binding_and_san_attacks),
            ("tampered-detached-sbom", self.test_tampered_detached_sbom_rejected),
            ("cosign-absent-vs-required", self.test_cosign_absent_vs_require_cosign),
            ("homebrew-isolation-and-cli", self.test_homebrew_isolation_and_cli_hygiene),
        )
        for shell_name, shell_path in self.shells.items():
            for suffix, fn in cases:
                label = f"{shell_name}-{suffix}"
                self.case(label, lambda s=shell_path, n=label, f=fn: f(s, n))
        return self.results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bash32", default="/bin/bash")
    parser.add_argument("--modern-bash", default="/opt/homebrew/bin/bash")
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    try:
        suite = Suite(args)
        results = suite.run()
        report = {
            "scratch": str(suite.scratch),
            "source_sha256": suite.source_hashes,
            "results": results,
            "passed": sum(r["passed"] for r in results),
            "failed": sum(not r["passed"] for r in results),
        }
    except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
        report = {"prerequisite_error": str(exc), "failed": 1}
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Receipt: {args.receipt}")
    return int(report["failed"] > 0)


if __name__ == "__main__":
    sys.exit(main())
