#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

# Load the maintenance functions without invoking the CLI.
# shellcheck source=cmd/local-package-maint.sh
source <(sed '$d' cmd/local-package-maint.sh)

# These bundles must reach their flake updater, even with unstable versions.
for package in awesome-copilot-skills matt-pocock-skills polars-skills ponytail-skills pstack-skills; do
    if [[ "${package}" == polars-skills ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" =~ ^0\.[0-9]+\.[0-9]+$ ]]
    elif [[ "${package}" == matt-pocock-skills || "${package}" == ponytail-skills ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    else
        [[ "$(package_version "${repo_root}" "${package}")" == unstable-* ]]
    fi
    [[ "$(update_mode "${repo_root}" "${package}")" == local-script ]]
    if reason="$(probe_skip_reason "${repo_root}" "${package}")"; then
        printf '%s must be updatable: %s\n' "${package}" "${reason}" >&2
        exit 1
    fi
done

if output="$(./cmd/local-package-maint.sh update nonexistent-regression-test-package 2>&1)"; then
    echo "Unknown packages must fail" >&2
    exit 1
fi
[[ "${output}" == *"Unknown local package: nonexistent-regression-test-package"* ]]

printf 'Package maintenance regression checks passed.\n'
