#!/usr/bin/env bash
# Refresh the unversioned upstream font without inventing a release version.
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"
pkg_file="${repo_root}/pkgs/pico-8-font/default.nix"

url="$(nix eval --raw .#pico-8-font.src.url)"
prefetch="$(nix store prefetch-file --refresh --name pico-8.ttf --json "${url}")"
source_hash="$(jq -er '.hash' <<<"${prefetch}")"
font_file="$(jq -er '.storePath' <<<"${prefetch}")"
if [[ -z "$(fc-scan --format '%{family}' "${font_file}")" ]]; then
    echo 'Downloaded PICO-8 file is not a valid font.' >&2
    exit 1
fi

original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

echo 'Refreshing pico-8-font source hash...'
sed -i -E "s#(sha256|hash) = \"[^\"]+\";#hash = \"${source_hash}\";#" "${pkg_file}"
echo 'Verifying nix build...'
nix build .#pico-8-font --no-link
trap - ERR
echo 'pico-8-font update complete.'
