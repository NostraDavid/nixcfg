#!/usr/bin/env bash
# Updates pkgs/whatpulse/default.nix to the latest Linux AppImage release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
  version="$(
    curl -fsSL https://whatpulse.org/releasenotes |
      grep -oE 'https://releases-dev\.whatpulse\.org/[0-9]+\.[0-9]+\.[0-9]+/linux/whatpulse-linux-[0-9]+\.[0-9]+\.[0-9]+_amd64\.AppImage' |
      sed -E 's#^https://releases-dev\.whatpulse\.org/([^/]+)/.*$#\1#' |
      head -n1
  )"
fi

if [[ -z "${version}" ]]; then
  echo 'Unable to determine latest WhatPulse version from releasenotes.' >&2
  exit 1
fi

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/whatpulse/default.nix"

printf 'Updating whatpulse to version %s\n' "${version}"

asset_url="https://releases-dev.whatpulse.org/${version}/linux/whatpulse-linux-${version}_amd64.AppImage"
prefetch_json="$(nix store prefetch-file --json "${asset_url}")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#whatpulse --no-link

echo 'whatpulse update complete.'
