#!/usr/bin/env bats
# Bats behavior and compatibility suite for scripts/verify-provenance.sh,
# scripts/update-readme-bottles.sh, and scripts/ci/* (`artagon-shell/shell-testing/v1`).
#
# Executes every target contract explicitly under both stock macOS Bash 3.2
# (`BATS_BASH32`) and modern Bash 5+ (`BATS_MODERN_BASH`) in isolated `HOME`,
# `TMPDIR`, and allowlisted `PATH` environments.

load helpers/provenance_helper

setup_file() {
  prov_setup_file_shared
}

setup() {
  if [[ "$BATS_TEST_DESCRIPTION" == "bash 3.2:"* ]] && [[ "${PROV_HAS_BASH32:-0}" -ne 1 ]]; then
    skip "macOS Bash 3.2 interpreter is not installed on $(uname -s)"
  fi
}

@test "bash 3.2: parse metadata across all bottled live Formula/*.rb files" {
  run case_parse_all_live_formulae "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: verify full SLSA v1, lineage, cosign, and SBOM fixture repo" {
  run case_full_verify_all_fixtures "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: encode revision, rebuild, @ (%40), and + (%2B) bottle subjects" {
  run case_revision_rebuild_encoding "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: parse explicit version stanza in Formula/*.rb" {
  run case_explicit_version_stanza "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: reject stale bottle block after version bump" {
  run case_stale_bottle_bump "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: export bundles and verify offline without curl or mutating bundle-dir" {
  run case_save_and_offline_roundtrip "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: reject corrupted bottle archive and mismatched .sha256 sidecar" {
  run case_corrupted_bottle_and_sidecar "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: reject missing -- subject, split-bundle subjects, and wrong SAN" {
  run case_subject_binding_and_san_attacks "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: reject tampered detached SPDX SBOM against lineage and DSSE" {
  run case_tampered_detached_sbom "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: skip absent cosign by default and fail under --require-cosign" {
  run case_cosign_absent_vs_required "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: isolate --homebrew trust/cache and clean TMPDIR on CLI errors" {
  run case_homebrew_isolation_and_cli "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: enforce README bottle table sync, common.sh state, and CI patch policy" {
  run case_readme_table_and_ci_patch_policy "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 3.2: verify multi-platform Linux and macOS bottles, --all-tags, and aligned bottle blocks" {
  run case_multi_tag_linux_and_macos "$PROV_BASH32"
  [ "$status" -eq 0 ]
}

@test "bash 5+: parse metadata across all bottled live Formula/*.rb files" {
  run case_parse_all_live_formulae "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: verify full SLSA v1, lineage, cosign, and SBOM fixture repo" {
  run case_full_verify_all_fixtures "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: encode revision, rebuild, @ (%40), and + (%2B) bottle subjects" {
  run case_revision_rebuild_encoding "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: parse explicit version stanza in Formula/*.rb" {
  run case_explicit_version_stanza "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: reject stale bottle block after version bump" {
  run case_stale_bottle_bump "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: export bundles and verify offline without curl or mutating bundle-dir" {
  run case_save_and_offline_roundtrip "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: reject corrupted bottle archive and mismatched .sha256 sidecar" {
  run case_corrupted_bottle_and_sidecar "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: reject missing -- subject, split-bundle subjects, and wrong SAN" {
  run case_subject_binding_and_san_attacks "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: reject tampered detached SPDX SBOM against lineage and DSSE" {
  run case_tampered_detached_sbom "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: skip absent cosign by default and fail under --require-cosign" {
  run case_cosign_absent_vs_required "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: isolate --homebrew trust/cache and clean TMPDIR on CLI errors" {
  run case_homebrew_isolation_and_cli "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: enforce README bottle table sync, common.sh state, and CI patch policy" {
  run case_readme_table_and_ci_patch_policy "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}

@test "bash 5+: verify multi-platform Linux and macOS bottles, --all-tags, and aligned bottle blocks" {
  run case_multi_tag_linux_and_macos "$PROV_MODERN_BASH"
  [ "$status" -eq 0 ]
}
