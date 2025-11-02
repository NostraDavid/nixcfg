#!/usr/bin/env bash
# Updates pkgs/opencode/default.nix to the desired upstream release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
  version="$(curl -s https://api.github.com/repos/sst/opencode/releases/latest | jq -r '.tag_name')"
fi

version="${version#v}"

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/opencode/default.nix"

printf 'Updating opencode to version %s\n' "${version}"

asset_url="https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.zip"
prefetch_json="$(nix store prefetch-file --json "${asset_url}")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s//hash = \"${source_hash}\";/" "${pkg_file}"

echo 'Attempting nix build to verify hash...'
nix build .#opencode --no-link

echo 'opencode update complete.'
