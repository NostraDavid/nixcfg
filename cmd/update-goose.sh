#!/usr/bin/env bash
# Updates pkgs/goose/default.nix to the desired upstream release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
	version="$(curl -fsSL https://api.github.com/repos/block/goose/releases/latest | jq -r '.tag_name // empty')"
fi

if [[ -z "${version}" ]]; then
	version="$(curl -fsSL 'https://api.github.com/repos/block/goose/releases?per_page=1' | jq -r '.[0].tag_name // empty')"
fi

if [[ -z "${version}" ]]; then
	echo 'Failed to determine latest goose release tag.' >&2
	exit 1
fi

version="${version#v}"

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/goose/default.nix"

printf 'Updating goose to version %s\n' "${version}"

asset_url="https://github.com/block/goose/releases/download/v${version}/goose-x86_64-unknown-linux-gnu.tar.bz2"
build_log="$(mktemp)"
cleanup() {
	rm -f "${build_log}"
}
trap cleanup EXIT

echo 'Determining archive hash...'
if nix build --impure --no-link --expr "let pkgs = import <nixpkgs> {}; in pkgs.fetchzip { url = \"${asset_url}\"; stripRoot = false; hash = pkgs.lib.fakeHash; }" >"${build_log}" 2>&1; then
	echo 'nix build unexpectedly succeeded while using fake hash placeholder.' >&2
	cat "${build_log}" >&2
	exit 1
fi

source_hash="$(grep -oE 'got:\s+sha256-[A-Za-z0-9+/=]+' "${build_log}" | awk '{print $2}' | tail -n1)"
if [[ -z "${source_hash}" ]]; then
	echo 'Failed to extract source hash from nix build output.' >&2
	cat "${build_log}" >&2
	exit 1
fi

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${pkg_file}"

echo 'Attempting nix build to verify hash...'
nix build .#goose --no-link

echo 'goose update complete.'
