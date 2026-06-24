#!/usr/bin/env bash
# Updates pkgs/bitnet/default.nix to the latest upstream snapshot.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/bitnet/default.nix"
api_url="https://api.github.com/repos/microsoft/BitNet/commits?per_page=1"
original_contents="$(cat "${pkg_file}")"

commit_json="$(curl -fsSL "${api_url}")"
rev="$(printf '%s' "${commit_json}" | jq -r '.[0].sha')"
commit_date="$(printf '%s' "${commit_json}" | jq -r '.[0].commit.committer.date')"

if [[ -z "${rev}" || "${rev}" == "null" || -z "${commit_date}" || "${commit_date}" == "null" ]]; then
	echo 'Failed to determine latest BitNet commit metadata.' >&2
	exit 1
fi

version="unstable-${commit_date%%T*}"

printf 'Updating bitnet to %s (%s)\n' "${version}" "${rev}"

build_log="$(mktemp)"
cleanup() {
	rm -f "${build_log}"
}
trap cleanup EXIT

echo 'Determining source hash...'
if nix build --impure --no-link --expr "let pkgs = import <nixpkgs> {}; in pkgs.fetchFromGitHub { owner = \"microsoft\"; repo = \"BitNet\"; rev = \"${rev}\"; fetchSubmodules = true; hash = pkgs.lib.fakeHash; }" >"${build_log}" 2>&1; then
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
sed -i "0,/rev = \".*\";/s//rev = \"${rev}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${new_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
if ! nix build .#bitnet --no-link; then
	printf '%s' "${original_contents}" >"${pkg_file}"
	echo 'Latest bitnet snapshot failed to build; restored the previous working package.' >&2
	exit 0
fi

echo 'bitnet update complete.'
