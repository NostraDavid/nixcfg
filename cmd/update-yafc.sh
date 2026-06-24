#!/usr/bin/env bash
# Updates pkgs/yafc/default.nix to the latest Debian source release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
	release_json="$(curl -fsSL 'https://sources.debian.org/api/src/yafc/')"
	version="$(printf '%s' "${release_json}" | jq -r '.versions[0].version // empty')"
fi

version="${version%%-*}"

if [[ -z "${version}" ]]; then
	echo 'Failed to determine latest yafc source version.' >&2
	exit 1
fi

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/yafc/default.nix"
asset_url="https://deb.debian.org/debian/pool/main/y/yafc/yafc_${version}.orig.tar.xz"

printf 'Updating yafc to version %s\n' "${version}"

prefetch_json="$(nix store prefetch-file --json "${asset_url}")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#yafc --no-link

echo 'yafc update complete.'
