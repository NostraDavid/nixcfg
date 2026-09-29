#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/gigatoken/default.nix"
cli_file="${repo_root}/pkgs/gigatoken/gigatoken.py"
version="${1:-}"
if [[ -z "$version" ]]; then
    version="$(curl -fsSL https://pypi.org/pypi/gigatoken/json | jq -er '.info.version')"
fi
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Unexpected gigatoken version: $version" >&2
    exit 1
}
release="$(curl -fsSL "https://pypi.org/pypi/gigatoken/${version}/json")"

pkg_backup="$(mktemp)"
cli_backup="$(mktemp)"
cp "$pkg_file" "$pkg_backup"
cp "$cli_file" "$cli_backup"
trap 'cp "$pkg_backup" "$pkg_file"; cp "$cli_backup" "$cli_file"' ERR
trap 'rm -f "$pkg_backup" "$cli_backup"' EXIT

sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "$pkg_file"
sed -i -E "s/version=\"%(prog)s [^\"]*\"/version=\"%(prog)s ${version}\"/" "$cli_file"
for system in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    case "$system" in
    x86_64-linux) suffix='manylinux_2_17_x86_64.manylinux2014_x86_64.whl' ;;
    aarch64-linux) suffix='manylinux_2_17_aarch64.manylinux2014_aarch64.whl' ;;
    x86_64-darwin) suffix='macosx_10_12_x86_64.whl' ;;
    aarch64-darwin) suffix='macosx_11_0_arm64.whl' ;;
    esac
    read -r url digest < <(jq -er --arg suffix "$suffix" 'first(.urls[] | select(.filename | endswith($suffix)) | [.url, .digests.sha256] | @tsv)' <<<"$release")
    hash="$(nix hash convert --hash-algo sha256 --to sri "$digest")"
    sed -i -E "/^    ${system} = \{/,/^    \};/ { s#url = \"[^\"]+\";#url = \"${url}\";#; s#hash = \"[^\"]+\";#hash = \"${hash}\";#; }" "$pkg_file"
done

cd "$repo_root"
nix build .#gigatoken --no-link
trap - ERR
printf 'gigatoken updated to %s\n' "$version"
