#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/t3code/default.nix"
release="$(gh api repos/pingdotgg/t3code/releases/latest)"
tag="$(jq -er '.tag_name' <<<"$release")"
version="${tag#v}"
[[ "$tag" == "v${version}" && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Unexpected T3 Code release tag: $tag" >&2
    exit 1
}
hash_for() {
    local digest
    digest="$(jq -er --arg name "$1" \
        '.assets[] | select(.name == $name) | .digest | select(test("^sha256:[0-9a-f]{64}$")) | sub("^sha256:"; "")' <<<"$release")"
    nix hash convert --hash-algo sha256 --to sri "$digest"
}
linux_hash="$(hash_for "T3-Code-${version}-x86_64.AppImage")"
darwin_hash="$(hash_for "T3-Code-${version}-arm64.zip")"

backup="$(mktemp)"
cp "$pkg_file" "$backup"
trap 'cp "$backup" "$pkg_file"' ERR
trap 'rm -f "$backup"' EXIT

sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "$pkg_file"
sed -i -E "s#linuxHash = \"[^\"]+\";#linuxHash = \"${linux_hash}\";#" "$pkg_file"
sed -i -E "s#darwinHash = \"[^\"]+\";#darwinHash = \"${darwin_hash}\";#" "$pkg_file"
cd "$repo_root"
nix build path:.#t3code --no-link
trap - ERR
printf 't3code updated to %s\n' "$version"
