#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

# Load the maintenance functions without invoking the CLI.
# shellcheck source=scripts/local-package-maint.sh
source <(sed '$d' scripts/local-package-maint.sh)

# These bundles must reach their flake updater, even with unstable versions.
for package in asd-ste100-skill awesome-copilot-skills databricks-agent-skills matt-pocock-skills pi-coding-agent-bun polars-skills ponytail-skills pstack-skills; do
    if [[ "${package}" == polars-skills ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" =~ ^0\.[0-9]+\.[0-9]+$ ]]
    elif [[ "${package}" == matt-pocock-skills || "${package}" == ponytail-skills ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    elif [[ "${package}" != pi-coding-agent-bun ]]; then
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
[[ "$(update_mode "${repo_root}" codex)" == local-script ]]
rg -q 'gh api repos/openai/codex/releases/latest' scripts/update-codex.sh
for package in cmux-tui fixit dockerfile-roast jsongrep mdschema gigatoken paperclip pico-8-font ponytail-codex uv; do
    [[ "$(update_mode "${repo_root}" "${package}")" == local-script ]]
done
for package in cmux-tui pico-8-font ponytail-codex; do
    list_packages | rg -x "${package}" >/dev/null
    if reason="$(probe_skip_reason "${repo_root}" "${package}")"; then
        printf '%s must be updatable: %s\n' "${package}" "${reason}" >&2
        exit 1
    fi
done

for package in espeak-ng sqlline tamzen-otf; do
    if reason="$(probe_skip_reason "${repo_root}" "${package}")"; then
        printf '%s must have a locally updatable version: %s\n' "${package}" "${reason}" >&2
        exit 1
    fi
    [[ "$(update_mode "${repo_root}" "${package}")" == embedded-nix-update ]]
    list_packages | rg -x "${package}" >/dev/null
done

# Generated outputs and input-derived packages have no independent update.
if list_packages | rg -q '^(forgejo-lab-image|proxmox-lab)$'; then
    echo 'Generated and explicitly managed packages must not be included in bulk updates' >&2
    exit 1
fi
[[ "$(probe_skip_reason "${repo_root}" forgejo-lab-image)" == *"generated flake output"* ]]

if output="$(./scripts/local-package-maint.sh update nonexistent-regression-test-package 2>&1)"; then
    echo "Unknown packages must fail" >&2
    exit 1
fi
[[ "${output}" == *"Unknown local package: nonexistent-regression-test-package"* ]]

# Exercise the public CLI against a real flake and a failing local updater.
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
mkdir -p "${test_root}/scripts" "${test_root}/pkgs/fixture"
cp scripts/local-package-maint.sh "${test_root}/scripts/"
cp scripts/github-auth.sh "${test_root}/scripts/"
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
cat >"${test_root}/scripts/update-fixture.sh" <<'EOF'
#!/usr/bin/env bash
echo 'fixture upstream connection failed' >&2
exit 19
EOF
git init -q "${test_root}"
git -C "${test_root}" add .
[[ "$(NIX_SYSTEM="${system}" bash "${test_root}/scripts/local-package-maint.sh" packages)" == fixture ]]
status=0
output="$(NIX_SYSTEM="${system}" bash "${test_root}/scripts/local-package-maint.sh" update fixture 2>&1)" || status=$?
[[ "${status}" -eq 19 ]]
[[ "${output}" == *"fixture upstream connection failed"* ]]
[[ "${output}" != *"Skipping update"* ]]
[[ "${output}" != *"retrying"* ]]
status=0
output="$(NIX_SYSTEM="${system}" bash "${test_root}/scripts/local-package-maint.sh" list fixture 2>&1)" || status=$?
[[ "${status}" -eq 1 ]]
[[ "${output}" == *"fixture upstream connection failed"* ]]
[[ "${output}" != *"No newer versions found"* ]]

# Temporary HTTP failures retry, but stop after three attempts.
mkdir -p "${test_root}/bin"
cat >"${test_root}/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == 'auth token' ]]
printf 'fixture-github-token\n'
EOF
chmod +x "${test_root}/bin/gh"
cat >"${test_root}/scripts/update-fixture.sh" <<'EOF'
#!/usr/bin/env bash
[[ "${GITHUB_TOKEN:-}" == fixture-github-token ]] || exit 20
[[ "${NIX_CONFIG:-}" == *'extra-access-tokens = github.com=fixture-github-token'* ]] || exit 20
attempts="$(dirname "$0")/attempts"
echo attempt >>"${attempts}"
if [[ "${FIXTURE_ALWAYS_FAIL:-0}" == 1 || "$(wc -l <"${attempts}")" -lt 3 ]]; then
    echo 'urllib.error.HTTPError: HTTP Error 504: Gateway Timeout' >&2
    exit 19
fi
echo 'fixture update complete.'
EOF
output="$(PATH="${test_root}/bin:${PATH}" GITHUB_TOKEN= NIX_SYSTEM="${system}" bash "${test_root}/scripts/local-package-maint.sh" update fixture 2>&1)"
[[ "$(wc -l <"${test_root}/scripts/attempts")" -eq 3 ]]
[[ "${output}" == *"fixture update complete."* ]]
[[ "${output}" != *fixture-github-token* ]]
rm "${test_root}/scripts/attempts"
status=0
output="$(PATH="${test_root}/bin:${PATH}" GITHUB_TOKEN= FIXTURE_ALWAYS_FAIL=1 NIX_SYSTEM="${system}" bash "${test_root}/scripts/local-package-maint.sh" update fixture 2>&1)" || status=$?
[[ "${status}" -eq 19 ]]
[[ "$(wc -l <"${test_root}/scripts/attempts")" -eq 3 ]]

# Exercise the real bulk recipe, including failures and its colour escapes.
just_bin="$(command -v just)"
mkdir -p "${test_root}/bin"
cat >"${test_root}/scripts/local-package-maint.sh" <<'EOF'
#!/usr/bin/env bash
printf 'good\nbad\ngood2\n'
EOF
cat >"${test_root}/bin/just" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$2" >>"${BULK_UPDATE_LOG}"
echo "verbose stdout for $2"
echo "verbose stderr for $2" >&2
[[ "$2" != bad ]]
EOF
chmod +x "${test_root}/scripts/local-package-maint.sh" "${test_root}/bin/just"
status=0
output="$(PATH="${test_root}/bin:${PATH}" BULK_UPDATE_LOG="${test_root}/bulk.log" \
    "${just_bin}" --justfile "${repo_root}/Justfile" --working-directory "${test_root}" pkg-update-all 2>&1)" || status=$?
[[ "${status}" -eq 1 ]]
[[ "$(cat "${test_root}/bulk.log")" == $'good\nbad\ngood2' ]]
[[ "${output}" == *$'\033[1m\033[31mPackages with failed updates:\033[0m'* ]]
[[ "${output}" == *$'\n  bad\n'* ]]
[[ "${output}" == *'good ... ok'* ]]
[[ "${output}" == *$'bad ... \033[31mFAILED\033[0m'* ]]
[[ "${output}" == *'good2 ... ok'* ]]
[[ "${output}" != *'verbose stdout for good'* ]]
[[ "${output}" != *'verbose stderr for good'* ]]
[[ "${output}" == *'verbose stdout for bad'* ]]
[[ "${output}" == *'verbose stderr for bad'* ]]

# Both flake-update recipes must authenticate before any Nix request.
printf '{"nodes":{"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}\n' >"${test_root}/flake.lock"
cat >"${test_root}/bin/nix" <<'EOF'
#!/usr/bin/env bash
[[ "${GITHUB_TOKEN:-}" == fixture-github-token ]] || exit 20
[[ "${NIX_CONFIG:-}" == *'extra-access-tokens = github.com=fixture-github-token'* ]] || exit 20
if [[ "$*" == *'flake metadata'* ]]; then
    printf '{"locks":{"nodes":{"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}}\n'
else
    printf '%s\n' "$*" >>"${FLAKE_UPDATE_LOG}"
fi
EOF
chmod +x "${test_root}/bin/nix"
for recipe in update update-nix; do
    PATH="${test_root}/bin:${PATH}" GITHUB_TOKEN= FLAKE_UPDATE_LOG="${test_root}/flake-updates.log" \
        "${just_bin}" --justfile "${repo_root}/Justfile" --working-directory "${test_root}" "${recipe}" >/dev/null
done
[[ "$(cat "${test_root}/flake-updates.log")" == $'flake update --option http-connections 1\nflake update --option http-connections 1 nixpkgs\nflake update --option http-connections 1 home-manager' ]]

printf 'Package maintenance regression checks passed.\n'
