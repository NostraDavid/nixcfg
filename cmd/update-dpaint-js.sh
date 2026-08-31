#!/usr/bin/env bash
# Updates pkgs/dpaint-js/default.nix to the latest upstream prerelease.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/dpaint-js/default.nix"
current_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";$/\1/p' "${pkg_file}" | head -n1)"

version="$(git ls-remote --tags --refs 'https://github.com/steffest/DPaint-js.git' |
    awk -F/ '$NF ~ /^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$/ { sub(/^v/, "", $NF); print $NF }' |
    sort -V |
    tail -n1)"

if [[ -z "${version}" || "${version}" == "null" ]]; then
    echo 'Failed to determine latest DPaint.js release metadata.' >&2
    exit 1
fi

if [[ "${version}" == "${current_version}" ]]; then
    printf 'dpaint-js is already at %s\n' "${version}"
    exit 0
fi

printf 'Updating dpaint-js to version %s\n' "${version}"

prefetch_json="$(nix store prefetch-file --json --unpack "https://github.com/steffest/DPaint-js/archive/refs/tags/v${version}.tar.gz")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#dpaint-js --no-link

echo 'dpaint-js update complete.'
