#!/usr/bin/env bash
# Updates pkgs/dlss-updater/default.nix to the latest upstream release.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/dlss-updater/default.nix"

release_json="$(curl -fsSL https://api.github.com/repos/Recol/DLSS-Updater/releases/latest)"
tag_name="$(printf '%s' "${release_json}" | jq -r '.tag_name')"
asset_url="$(printf '%s' "${release_json}" | jq -r '.assets[] | select(.browser_download_url | endswith(".flatpak")) | .browser_download_url' | head -n1)"

if [[ -z "${tag_name}" || "${tag_name}" == "null" || -z "${asset_url}" ]]; then
  echo 'Failed to determine latest DLSS Updater release metadata.' >&2
  exit 1
fi

version="${tag_name#V}"
version="${version#v}"

printf 'Updating dlss-updater to version %s\n' "${version}"

prefetch_json="$(nix store prefetch-file --json "${asset_url}")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#dlss-updater --no-link

echo 'dlss-updater update complete.'
