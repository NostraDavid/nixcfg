#!/usr/bin/env bash

set -euo pipefail

# Recipe regression tests must never start a billable Codex session.
export NIXCFG_CODEX_REVIEW=0

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

# Load the maintenance functions without invoking the CLI.
# shellcheck source=scripts/local-package-maint.sh
source <(sed '$d' scripts/local-package-maint.sh)

selection=$'codex\nforgejo-lab-image\nopencode-v2\npaperclip\nheadlamp-identity'
[[ $(NIXCFG_BULK_HOST=wodan filter_bulk_packages <<<"$selection") == $'codex\nopencode-v2' ]]
[[ $(NIXCFG_BULK_HOST=mimir2 filter_bulk_packages <<<"$selection") == "$selection" ]]

skip_reason_for() {
    local metadata
    metadata="$(package_metadata "$repo_root" "$1")" || return 1
    probe_skip_reason "$repo_root" "$1" "$metadata"
}

# These bundles must reach their flake updater, even with unstable versions.
for package in asd-ste100-skill awesome-copilot-skills databricks-agent-skills matt-pocock-skills polars-skills ponytail-skills pstack-skills; do
    if [[ "${package}" == polars-skills ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" =~ ^0\.[0-9]+\.[0-9]+$ ]]
    elif [[ "${package}" == matt-pocock-skills || "${package}" == ponytail-skills ]]; then
        [[ "$(package_version "${repo_root}" "${package}")" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    else
        [[ "$(package_version "${repo_root}" "${package}")" == unstable-* ]]
    fi
    if [[ "$(update_mode "${repo_root}" "${package}")" != local-script ]]; then
        printf '%s must use its flake-input updater\n' "${package}" >&2
        exit 1
    fi
    if reason="$(skip_reason_for "${package}")"; then
        printf '%s must be updatable: %s\n' "${package}" "${reason}" >&2
        exit 1
    fi
done

[[ "$(package_update_script "${repo_root}" espeak-ng)" == *"--version branch"* ]]
[[ "$(update_mode "${repo_root}" codex)" == local-script ]]
for package in herdr-app herdr-core; do
    [[ "$(update_mode "${repo_root}" "${package}")" == local-script ]]
done
rg -q 'gh api repos/openai/codex/releases/latest' scripts/update-codex.sh
for package in dockerfile-roast gigatoken paperclip ponytail-codex; do
    [[ "$(update_mode "${repo_root}" "${package}")" == local-script ]]
done
list_packages | rg -x ponytail-codex >/dev/null
if reason="$(skip_reason_for ponytail-codex)"; then
    printf 'ponytail-codex must be updatable: %s\n' "${reason}" >&2
    exit 1
fi

if reason="$(skip_reason_for espeak-ng)"; then
    printf 'espeak-ng must have a locally updatable version: %s\n' "$reason" >&2
    exit 1
fi
[[ "$(update_mode "${repo_root}" espeak-ng)" == embedded-nix-update ]]
list_packages | rg -x espeak-ng >/dev/null
[[ "$(skip_reason_for tamzen-otf)" == *nixpkgs.tamzen* ]]
for package in acli mdschema uv; do
    [[ "$(skip_reason_for "$package")" == *"flake inputs"* ]]
done

# Generated outputs and input-derived packages have no independent update.
if list_packages | rg -q '^(forgejo-lab-image|proxmox-lab)$'; then
    echo 'Generated and explicitly managed packages must not be included in bulk updates' >&2
    exit 1
fi
[[ "$(skip_reason_for forgejo-lab-image)" == *"generated flake output"* ]]

if output="$(./scripts/local-package-maint.sh update nonexistent-regression-test-package 2>&1)"; then
    echo "Unknown packages must fail" >&2
    exit 1
fi
[[ "${output}" == *"Unknown local package: nonexistent-regression-test-package"* ]]

# Exercise the public CLI against a real flake and a failing local updater.
test_root="$(mktemp -d)"
bulk_log_dirs=()
trap 'rm -rf "${test_root}" "${bulk_log_dirs[@]}"' EXIT
mkdir -p "${test_root}/scripts" "${test_root}/pkgs/fixture"
cp scripts/local-package-maint.sh "${test_root}/scripts/"
cp scripts/github-auth.sh scripts/update-review.py "${test_root}/scripts/"
cat >"${test_root}/flake.nix" <<EOF
{
  outputs = _: {
    packages.${system} = {
      fixture = { version = "1.0.0"; passthru = {}; };
      bitbucket-cli = { version = "1.9.0"; };
      generated = {};
    };
  };
}
EOF
touch "${test_root}/pkgs/fixture/default.nix"
cat >"${test_root}/scripts/update-fixture.sh" <<'EOF'
#!/usr/bin/env bash
if [[ ${NIXCFG_SKIP_UNCHANGED:-0} == 1 ]]; then
    [[ ${NIXCFG_CURRENT_VERSION:-} == 1.0.0 ]]
    exit
fi
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
NIXCFG_SKIP_UNCHANGED=1 NIX_SYSTEM="${system}" bash "${test_root}/scripts/local-package-maint.sh" update fixture
status=0
output="$(NIX_SYSTEM="${system}" bash "${test_root}/scripts/local-package-maint.sh" list fixture 2>&1)" || status=$?
[[ "${status}" -eq 1 ]]
[[ "${output}" == *"fixture upstream connection failed"* ]]
[[ "${output}" != *"No newer versions found"* ]]

# Tag probes must work in the original checkout with only release metadata.
mkdir -p "${test_root}/pkgs/bitbucket-cli" "${test_root}/bin"
touch "${test_root}/pkgs/bitbucket-cli/default.nix"
cp scripts/update-prebuilt-github.sh "${test_root}/scripts/"
ln -s update-prebuilt-github.sh "${test_root}/scripts/update-bitbucket-cli.sh"
git -C "${test_root}" add pkgs/bitbucket-cli scripts
cat >"${test_root}/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$PWD" == "$PROBE_ROOT" && "$*" == 'api repos/avivsinai/bitbucket-cli/releases/latest' ]] || exit 1
printf '{"tag_name":"%s"}\n' "$PROBE_TAG"
EOF
chmod +x "${test_root}/bin/gh"
probe() {
    local tag="$1"
    shift
    PROBE_ROOT="${test_root}" PROBE_TAG="$tag" PATH="${test_root}/bin:$PATH" \
        NIX_SYSTEM="${system}" bash "${test_root}/scripts/local-package-maint.sh" list "$@" 2>&1
}
[[ "$(probe 1.10.0 bitbucket-cli)" == 'bitbucket-cli 1.9.0 -> 1.10.0' ]]
for tag in 1.9.0 1.8.0; do
    [[ "$(probe "$tag" bitbucket-cli)" == 'No newer versions found.' ]]
done
if output="$(probe broken bitbucket-cli fixture)"; then exit 1; fi
[[ "$output" == *'Unexpected release tag: broken'* && "$output" == *'fixture upstream connection failed'* ]]
[[ ! -s "${test_root}/pkgs/bitbucket-cli/default.nix" ]]

# Temporary HTTP failures retry, but stop after three attempts.
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
if [[ "${BULK_SCENARIO}" == discovery-failure ]]; then
    echo 'fixture package discovery failed' >&2
    exit 19
fi
printf 'good\nbad\nupdated\ngood2\n'
EOF
cat >"${test_root}/bin/just" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$2" >>"${BULK_UPDATE_LOG}"
echo "verbose stdout for $2"
echo "verbose stderr for $2" >&2
if [[ "$2" == updated ]]; then echo changed >>tracked; fi
[[ "$2" != bad || "${BULK_SCENARIO}" == success ]]
EOF
chmod +x "${test_root}/scripts/local-package-maint.sh" "${test_root}/bin/just"
echo original >"${test_root}/tracked"
git -C "${test_root}" add tracked
echo 'previous change' >>"${test_root}/tracked"
for scenario in failure success discovery-failure; do
    : >"${test_root}/bulk.log"
    status=0
    output="$(PATH="${test_root}/bin:${PATH}" BULK_UPDATE_LOG="${test_root}/bulk.log" BULK_SCENARIO="${scenario}" \
        "${just_bin}" --justfile "${repo_root}/Justfile" --working-directory "${test_root}" pkgs 2>&1)" || status=$?
    log_dir="$(sed -n 's/^Logs: //p' <<<"${output}")"
    [[ "${log_dir}" == /tmp/just-pkgs.* ]]
    bulk_log_dirs+=("${log_dir}")
    [[ "$(stat -c '%a' "${log_dir}")" == 700 ]]
    [[ -f "${log_dir}/output.log" ]]
    [[ "${output}" == "$(cat "${log_dir}/output.log")"* ]]
    if [[ "${scenario}" == discovery-failure ]]; then
        [[ "${status}" -eq 19 ]]
        [[ ! -s "${test_root}/bulk.log" ]]
        [[ "$(cat "${log_dir}/output.log")" == 'fixture package discovery failed' ]]
        continue
    fi
    [[ "$(cat "${test_root}/bulk.log")" == $'good\nbad\nupdated\ngood2' ]]
    for package in good bad updated good2; do
        [[ "$(cat "${log_dir}/${package}.log")" == "verbose stdout for ${package}"$'\n'"verbose stderr for ${package}" ]]
    done
    [[ "${output}" == *$'good ... \033[32mno update\033[0m'* ]]
    [[ "${output}" == *$'updated ... \033[34mupdated\033[0m'* ]]
    [[ "${output}" == *$'good2 ... \033[32mno update\033[0m'* ]]
    [[ "${output}" != *'verbose stdout for good'* ]]
    [[ "${output}" != *'verbose stderr for good'* ]]
    if [[ "${scenario}" == failure ]]; then
        [[ "${status}" -eq 1 ]]
        [[ "${output}" == *$'\033[1m\033[31mPackages with failed updates:\033[0m'* ]]
        [[ "${output}" == *$'\n  bad\n'* ]]
        [[ "${output}" == *$'bad ... \033[31mFAILED\033[0m'* ]]
        [[ "${output}" == *'verbose stdout for bad'* ]]
        [[ "${output}" == *'verbose stderr for bad'* ]]
    else
        [[ "${status}" -eq 0 ]]
        [[ "${output}" != *FAILED* ]]
        [[ "${output}" != *'verbose stdout for bad'* ]]
        [[ "${output}" != *'verbose stderr for bad'* ]]
    fi
done

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
    output="$(PATH="${test_root}/bin:${PATH}" GITHUB_TOKEN= FLAKE_UPDATE_LOG="${test_root}/flake-updates.log" \
        "${just_bin}" --justfile "${repo_root}/Justfile" --working-directory "${test_root}" "${recipe}")"
    if [[ "${recipe}" == update ]]; then
        log_dir="$(sed -n 's/^Logs: //p' <<<"${output}")"
        [[ "${log_dir}" == /tmp/just-update.* && -f "${log_dir}/output.log" ]]
        bulk_log_dirs+=("${log_dir}")
    fi
done
[[ "$(cat "${test_root}/flake-updates.log")" == $'flake update --option http-connections 1\nflake update --option http-connections 1 nixpkgs\nflake update --option http-connections 1 home-manager' ]]

printf 'Package maintenance regression checks passed.\n'
