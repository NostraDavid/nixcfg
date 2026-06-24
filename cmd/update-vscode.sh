#!/usr/bin/env bash
# Updates pkgs/vscode/default.nix to the latest stable VS Code build.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
	version="$(curl -fsSL https://update.code.visualstudio.com/api/releases/stable | jq -r '.[0] // empty')"
fi

if [[ -z "${version}" || "${version}" == "null" ]]; then
	echo 'Failed to determine latest VS Code stable release.' >&2
	exit 1
fi

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/vscode/default.nix"
asset_url="https://update.code.visualstudio.com/${version}/linux-x64/stable"

printf 'Updating vscode to version %s\n' "${version}"

prefetch_json="$(nix store prefetch-file --json "${asset_url}")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i "0,/srcHash = \".*\";/s#srcHash = \".*\";#srcHash = \"${source_hash}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#vscode --no-link

echo 'vscode update complete.'
