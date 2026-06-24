#!/usr/bin/env bash
# Updates pkgs/cool-retro-term/default.nix to the latest upstream prerelease.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/cool-retro-term/default.nix"
current_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";$/\1/p' "${pkg_file}" | head -n1)"

release_json="$(curl -fsSL 'https://api.github.com/repos/Swordfish90/cool-retro-term/releases?per_page=1')"
version="$(printf '%s' "${release_json}" | jq -r '.[0].tag_name')"
version="${version#v}"

if [[ -z "${version}" || "${version}" == "null" ]]; then
	echo 'Failed to determine latest cool-retro-term release metadata.' >&2
	exit 1
fi

if [[ "${version}" == "${current_version}" ]]; then
	printf 'cool-retro-term is already at %s\n' "${version}"
	exit 0
fi

printf 'Updating cool-retro-term to version %s\n' "${version}"

build_log="$(mktemp)"
cleanup() {
	rm -f "${build_log}"
}
trap cleanup EXIT

if nix build --impure --no-link --expr "let pkgs = import <nixpkgs> {}; in pkgs.fetchFromGitHub { owner = \"Swordfish90\"; repo = \"cool-retro-term\"; tag = \"${version}\"; fetchSubmodules = true; hash = pkgs.lib.fakeHash; }" >"${build_log}" 2>&1; then
	echo 'nix build unexpectedly succeeded while using fake hash placeholder.' >&2
	cat "${build_log}" >&2
	exit 1
fi

new_hash="$(grep -oE 'got:\s+sha256-[A-Za-z0-9+/=]+' "${build_log}" | awk '{print $2}' | tail -n1)"
if [[ -z "${new_hash}" ]]; then
	echo 'Failed to extract source hash from nix build output.' >&2
	cat "${build_log}" >&2
	exit 1
fi

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${new_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#cool-retro-term --no-link

echo 'cool-retro-term update complete.'
