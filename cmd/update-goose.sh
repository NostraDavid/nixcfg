#!/usr/bin/env bash
# Updates pkgs/goose/default.nix to the desired upstream release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
  version="$(curl -s https://api.github.com/repos/block/goose/releases/latest | jq -r '.tag_name')"
fi

version="${version#v}"

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/goose/default.nix"

printf 'Updating goose to version %s\n' "${version}"

asset_url="https://github.com/block/goose/releases/download/v${version}/goose-x86_64-unknown-linux-gnu.tar.bz2"
prefetch_json="$(nix store prefetch-file --json "${asset_url}")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s//hash = \"${source_hash}\";/" "${pkg_file}"

echo 'Attempting nix build to verify hash...'
nix build .#goose --no-link

echo 'goose update complete.'
