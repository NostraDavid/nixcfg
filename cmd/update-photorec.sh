#!/usr/bin/env bash
# Updates pkgs/photorec/default.nix to the latest stable TestDisk/PhotoRec build.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
  version="$(
    curl -fsSL https://www.cgsecurity.org/wiki/TestDisk_Download |
      grep -oE 'TestDisk &amp; PhotoRec [0-9]+([.][0-9]+)+ [(]' |
      head -n1 |
      grep -oE '[0-9]+([.][0-9]+)+'
  )"
fi

if [[ -z "${version}" ]]; then
  echo 'Failed to determine latest stable TestDisk/PhotoRec release.' >&2
  exit 1
fi

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/photorec/default.nix"
current_version="$(nix eval --raw .#photorec.version)"
asset_url="https://www.cgsecurity.org/testdisk-${version}.linux26-x86_64.tar.bz2"

if [[ "${version}" == "${current_version}" ]]; then
  printf 'photorec is already at latest stable version %s\n' "${version}"
  exit 0
fi

printf 'Updating photorec to version %s\n' "${version}"

prefetch_json="$(nix store prefetch-file --json --unpack "${asset_url}")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#photorec --no-link

echo 'photorec update complete.'
