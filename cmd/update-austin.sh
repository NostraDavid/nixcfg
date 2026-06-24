#!/usr/bin/env bash
# Updates pkgs/austin/default.nix to the latest upstream release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
	version="$(curl -fsSL https://api.github.com/repos/P403n1x87/austin/releases/latest | jq -r '.tag_name')"
fi

version="${version#v}"

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/austin/default.nix"

printf 'Updating austin to version %s\n' "${version}"

prefetch_json="$(nix store prefetch-file --json --unpack "https://github.com/P403n1x87/austin/archive/refs/tags/v${version}.tar.gz")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#austin --no-link

echo 'austin update complete.'
