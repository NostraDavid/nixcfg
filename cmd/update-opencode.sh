#!/usr/bin/env bash
# Updates pkgs/opencode/default.nix to the desired upstream release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
  # resolve latest release via GitHub API when no version supplied
  version="$(curl -fsSL https://api.github.com/repos/sst/opencode/releases/latest | jq -r '.tag_name')"
fi

version="${version#v}"

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/opencode/default.nix"

printf 'Updating opencode to version %s\n' "${version}"

build_log="$(mktemp)"
cleanup() {
  rm -f "${build_log}"
}
trap cleanup EXIT

asset_url="https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.zip"

echo 'Determining archive hash...'
if nix build --impure --no-link --expr "let pkgs = import <nixpkgs> {}; in pkgs.fetchzip { url = \"${asset_url}\"; stripRoot = false; hash = pkgs.lib.fakeHash; }" >"${build_log}" 2>&1; then
  echo 'nix build unexpectedly succeeded while using fake hash placeholder.' >&2
  cat "${build_log}" >&2
  exit 1
fi

grep_output="$(grep -oE 'got:\s+sha256-[A-Za-z0-9+/=]+' "${build_log}" || true)"
new_hash="$(printf '%s\n' "${grep_output}" | awk '{print $2}' | tail -n1)"
if [[ -z "${new_hash}" ]]; then
  echo 'Failed to extract hash from nix build output.' >&2
  cat "${build_log}" >&2
  exit 1
fi

# bump version and hash in default.nix
sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${new_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#opencode --no-link

echo 'opencode update complete.'
