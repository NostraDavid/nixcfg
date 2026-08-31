#!/usr/bin/env bash
# Updates the Apache Hadoop command-line distribution.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/hadoop-cli/default.nix"
current_version="$(sed -n 's/^[[:space:]]*version [?] "\([^"]*\)",$/\1/p' "${pkg_file}" | head -n1)"
version="$(curl -fsSL 'https://downloads.apache.org/hadoop/common/stable/' |
    grep -oE 'hadoop-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' |
    sed -E 's/^hadoop-([0-9.]+)\.tar\.gz$/\1/' |
    sort -V |
    tail -n1)"

[[ -n "${version}" ]] || {
    echo 'Failed to determine the latest Hadoop version.' >&2
    exit 1
}

if [[ "${version}" == "${current_version}" ]]; then
    printf 'hadoop-cli is already at %s\n' "${version}"
    exit 0
fi

url="https://downloads.apache.org/hadoop/common/hadoop-${version}/hadoop-${version}.tar.gz"
source_hash="$(nix store prefetch-file --json "${url}" | jq -er '.hash')"
original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating hadoop-cli to version %s\n' "${version}"
sed -i -E "s/version \? \"[^\"]+\",/version ? \"${version}\",/" "${pkg_file}"
sed -i -E "s/sha256 \? \"[^\"]+\",/sha256 ? \"${source_hash}\",/" "${pkg_file}"

cd "${repo_root}"
echo 'Verifying nix build...'
nix build .#hadoop-cli --no-link
trap - ERR
echo 'hadoop-cli update complete.'
