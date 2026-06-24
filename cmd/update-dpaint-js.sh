#!/usr/bin/env bash
# Updates pkgs/dpaint-js/default.nix to the latest upstream prerelease.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/dpaint-js/default.nix"

release_json="$(curl -fsSL 'https://api.github.com/repos/steffest/DPaint-js/releases?per_page=1')"
version="$(printf '%s' "${release_json}" | jq -r '.[0].tag_name')"
version="${version#v}"

if [[ -z "${version}" || "${version}" == "null" ]]; then
	echo 'Failed to determine latest DPaint.js release metadata.' >&2
	exit 1
fi

printf 'Updating dpaint-js to version %s\n' "${version}"

prefetch_json="$(nix store prefetch-file --json --unpack "https://github.com/steffest/DPaint-js/archive/refs/tags/v${version}.tar.gz")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#dpaint-js --no-link

echo 'dpaint-js update complete.'
