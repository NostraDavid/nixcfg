#!/usr/bin/env bash
# Updates dockerfile-roast from its version tags.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/dockerfile-roast/default.nix"
current_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";$/\1/p' "${pkg_file}" | head -n1)"
version="$(git ls-remote --tags --refs 'https://github.com/immanuwell/dockerfile-roast.git' |
    awk -F/ '$NF ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ { print $NF }' |
    sort -V |
    tail -n1)"

[[ -n "${version}" ]] || {
    echo 'Failed to determine the latest dockerfile-roast version.' >&2
    exit 1
}

if [[ "${version}" == "${current_version}" ]]; then
    printf 'dockerfile-roast is already at %s\n' "${version}"
    exit 0
fi

source_hash="$(nix store prefetch-file --json --unpack "https://github.com/immanuwell/dockerfile-roast/archive/refs/tags/${version}.tar.gz" | jq -er '.hash')"
original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

replace_cargo_hash() {
    local new_hash="$1"
    sed -i -E "s#cargoHash = \"[^\"]+\";#cargoHash = \"${new_hash}\";#" "${pkg_file}"
}

printf 'Updating dockerfile-roast to version %s\n' "${version}"
sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "${pkg_file}"
sed -i -E "/src = fetchFromGitHub/,/};/ s#hash = \"[^\"]+\";#hash = \"${source_hash}\";#" "${pkg_file}"

build_log="$(mktemp)"
replace_cargo_hash 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
if nix build .#dockerfile-roast --no-link >"${build_log}" 2>&1; then
    echo 'Unexpectedly built with a fake Cargo hash.' >&2
    cat "${build_log}" >&2
    rm -f "${build_log}"
    restore
    exit 1
fi

cargo_hash="$(sed -n 's/.*got:[[:space:]]*\(sha256-[^[:space:]]*\).*/\1/p' "${build_log}" | tail -n1)"
if [[ -z "${cargo_hash}" ]]; then
    cat "${build_log}" >&2
    rm -f "${build_log}"
    restore
    exit 1
fi

replace_cargo_hash "${cargo_hash}"
echo 'Verifying nix build...'
if ! nix build .#dockerfile-roast --no-link >>"${build_log}" 2>&1; then
    cat "${build_log}" >&2
    rm -f "${build_log}"
    restore
    exit 1
fi
rm -f "${build_log}"
trap - ERR
echo 'dockerfile-roast update complete.'
