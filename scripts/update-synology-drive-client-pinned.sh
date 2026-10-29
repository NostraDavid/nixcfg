#!/usr/bin/env bash
# Updates the pinned Synology Drive Client installers.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/synology-drive-client-pinned/default.nix"
version="${1:-}"

if [[ -z "${version}" ]]; then
    version="$(curl -fsSL 'https://www.synology.com/api/releaseNote/findChangeLog?identify=SynologyDriveClient&lang=en-uk' | jq -er '[.info.versions[].all_versions[].version | select(test("^[0-9]+(\\.[0-9]+)+-[0-9]+$"))] | max_by(split("[.-]"; "") | map(tonumber))')"
fi

current_version="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*/\1/p' "${pkg_file}")"
if ! jq -en --arg version "${version}" --arg current "${current_version}" '
    def parts: if test("^[0-9]+(\\.[0-9]+)+-[0-9]+$") then split("[.-]"; "") | map(tonumber) else error("Invalid version") end;
    ($version | parts) >= ($current | parts)
' >/dev/null; then
    echo "Refusing invalid version or downgrade: ${current_version} -> ${version}" >&2
    exit 1
fi

build="${version##*-}"
base_url="https://global.synologydownload.com/download/Utility/SynologyDriveClient"
linux_url="${base_url}/${version}/Ubuntu/Installer/synology-drive-client-${build}.x86_64.deb"
darwin_url="${base_url}/${version}/Mac/Installer/synology-drive-client-${build}.dmg"
linux_hash="$(nix store prefetch-file --json "${linux_url}" | jq -er '.hash')"
darwin_hash="$(nix store prefetch-file --json "${darwin_url}" | jq -er '.hash')"

original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating synology-drive-client to version %s\n' "${version}"
sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "${pkg_file}"
sed -i -E "/linuxSrc = fetchurl/,/};/ s#hash = \"[^\"]+\";#hash = \"${linux_hash}\";#" "${pkg_file}"
sed -i -E "/darwinSrc = fetchurl/,/};/ s#hash = \"[^\"]+\";#hash = \"${darwin_hash}\";#" "${pkg_file}"

cd "${repo_root}"
echo 'Verifying nix build...'
nix build .#synology-drive-client-pinned --no-link
trap - ERR
echo 'synology-drive-client update complete.'
