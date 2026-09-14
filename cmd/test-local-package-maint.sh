#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

# Load the maintenance functions without invoking the CLI.
# shellcheck source=cmd/local-package-maint.sh
source <(sed '$d' cmd/local-package-maint.sh)

# These bundles must reach their flake updater, even with unstable versions.
for package in awesome-copilot-skills blender-mcp-skills blender-reference-skills cc-blender-skills hermes-agent-desktop matt-pocock-skills pi-coding-agent-bun polars-skills ponytail-skills pstack-skills; do
    if [[ "${package}" == polars-skills ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" =~ ^0\.[0-9]+\.[0-9]+$ ]]
    elif [[ "${package}" == matt-pocock-skills || "${package}" == ponytail-skills ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    elif [[ "${package}" != cc-blender-skills && "${package}" != hermes-agent-desktop && "${package}" != pi-coding-agent-bun ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" == unstable-* ]]
    fi
    if [[ "$(update_mode "${repo_root}" "${package}")" != local-script ]]; then
        printf '%s must use its flake-input updater\n' "${package}" >&2
        exit 1
    fi
    if reason="$(probe_skip_reason "${repo_root}" "${package}")"; then
        printf '%s must be updatable: %s\n' "${package}" "${reason}" >&2
        exit 1
    fi
done

[[ "$(update_mode "${repo_root}" creep2)" == embedded-nix-update ]]
[[ "$(package_update_script "${repo_root}" creep2)" == *"--version branch"* ]]
[[ "$(package_update_script "${repo_root}" codex)" == *"--use-github-releases"* ]]

for package in say-dictionary sqlline tamzen-otf; do
    if reason="$(probe_skip_reason "${repo_root}" "${package}")"; then
        printf '%s must have a locally updatable version: %s\n' "${package}" "${reason}" >&2
        exit 1
    fi
    [[ "$(update_mode "${repo_root}" "${package}")" == embedded-nix-update ]]
    list_packages | rg -x "${package}" >/dev/null
done

# Generated outputs have no independent upstream package to update.
if list_packages | rg -q '^(forgejo-lab-image|proxmox-lab|pico-8-font)$'; then
    echo 'Generated and explicitly managed packages must not be included in bulk updates' >&2
    exit 1
fi
[[ "$(probe_skip_reason "${repo_root}" forgejo-lab-image)" == *"generated flake output"* ]]

if output="$(./cmd/local-package-maint.sh update nonexistent-regression-test-package 2>&1)"; then
    echo "Unknown packages must fail" >&2
    exit 1
fi
[[ "${output}" == *"Unknown local package: nonexistent-regression-test-package"* ]]

# Exercise the public CLI against a real flake and a failing local updater.
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
mkdir -p "${test_root}/cmd" "${test_root}/pkgs/fixture"
cp cmd/local-package-maint.sh "${test_root}/cmd/"
cat >"${test_root}/flake.nix" <<EOF
{
  outputs = _: {
    packages.${system} = {
      fixture = { version = "1.0.0"; passthru = {}; };
      generated = {};
    };
  };
}
EOF
touch "${test_root}/pkgs/fixture/default.nix"
cat >"${test_root}/cmd/update-fixture.sh" <<'EOF'
#!/usr/bin/env bash
echo 'fixture upstream connection failed' >&2
exit 19
EOF
git init -q "${test_root}"
git -C "${test_root}" add .
[[ "$(NIX_SYSTEM="${system}" bash "${test_root}/cmd/local-package-maint.sh" packages)" == fixture ]]
status=0
output="$(NIX_SYSTEM="${system}" bash "${test_root}/cmd/local-package-maint.sh" update fixture 2>&1)" || status=$?
[[ "${status}" -eq 19 ]]
[[ "${output}" == *"fixture upstream connection failed"* ]]
[[ "${output}" != *"Skipping update"* ]]
status=0
output="$(NIX_SYSTEM="${system}" bash "${test_root}/cmd/local-package-maint.sh" list fixture 2>&1)" || status=$?
[[ "${status}" -eq 1 ]]
[[ "${output}" == *"fixture upstream connection failed"* ]]
[[ "${output}" != *"No newer versions found"* ]]

printf 'Package maintenance regression checks passed.\n'
