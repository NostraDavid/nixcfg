#!/usr/bin/env bash
# Update libjpeg-turbo from stable releases and jpegli from upstream HEAD.
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/jpegli/default.nix"
version="$(curl --fail --silent --show-error https://api.github.com/repos/libjpeg-turbo/libjpeg-turbo/releases/latest | jq -er '.tag_name')"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || {
    echo "Unexpected libjpeg-turbo release tag: ${version}" >&2
    exit 1
}
source_hash="$(nix store prefetch-file --json --unpack "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${version}/libjpeg-turbo-${version}.tar.gz" | jq -er '.hash')"
original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating jpegli dependency libjpeg-turbo to %s\n' "${version}"
sed -i -E "s/libjpegTurboVersion = \"[^\"]+\";/libjpegTurboVersion = \"${version}\";/" "${pkg_file}"
sed -i -E "/libjpegTurboSrc = fetchzip/,/};/ s#hash = \"[^\"]+\";#hash = \"${source_hash}\";#" "${pkg_file}"
"${repo_root}/cmd/update-github-unstable.sh" jpegli google jpegli

# The shared updater skips its build when jpegli HEAD has not changed.
cd "${repo_root}"
nix build .#jpegli --no-link
trap - ERR
echo 'jpegli and its libjpeg-turbo dependency update complete.'
