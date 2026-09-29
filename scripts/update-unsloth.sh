#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/unsloth/default.nix"
release="$(curl -fsSL 'https://api.github.com/repos/unslothai/unsloth/releases?per_page=100' |
    jq -cer 'first(.[] | select(any(.assets[]; .name == "Unsloth-Desktop-Linux.AppImage")))')"
tag="$(jq -er '.tag_name' <<<"$release")"
version="${tag#v}"
[[ "$tag" == "v${version}" && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] || {
    echo "Unexpected Unsloth release tag: $tag" >&2
    exit 1
}
digest="$(jq -er '.assets[] | select(.name == "Unsloth-Desktop-Linux.AppImage") | .digest | select(startswith("sha256:")) | sub("^sha256:"; "")' <<<"$release")"
hash="$(nix hash convert --hash-algo sha256 --to sri "$digest")"

backup="$(mktemp)"
cp "$pkg_file" "$backup"
trap 'cp "$backup" "$pkg_file"' ERR
trap 'rm -f "$backup"' EXIT

sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "$pkg_file"
sed -i -E "s#hash = \"[^\"]+\";#hash = \"${hash}\";#" "$pkg_file"
cd "$repo_root"
nix build path:.#unsloth --no-link
trap - ERR
printf 'unsloth updated to %s\n' "$version"
