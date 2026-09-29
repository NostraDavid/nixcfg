#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/probe/default.nix"
release="$(curl -fsSL https://api.github.com/repos/probelabs/probe/releases/latest)"
tag="$(jq -er '.tag_name' <<<"$release")"
version="${tag#v}"
[[ "$tag" == "v${version}" && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] || {
    echo "Unexpected Probe release tag: $tag" >&2
    exit 1
}

backup="$(mktemp)"
cp "$pkg_file" "$backup"
trap 'cp "$backup" "$pkg_file"' ERR
trap 'rm -f "$backup"' EXIT

sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "$pkg_file"
for system in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    case "$system" in
    x86_64-linux) target=x86_64-unknown-linux-musl ;;
    aarch64-linux) target=aarch64-unknown-linux-musl ;;
    x86_64-darwin) target=x86_64-apple-darwin ;;
    aarch64-darwin) target=aarch64-apple-darwin ;;
    esac
    asset="probe-v${version}-${target}.tar.gz"
    digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest | select(startswith("sha256:")) | sub("^sha256:"; "")' <<<"$release")"
    hash="$(nix hash convert --hash-algo sha256 --to sri "$digest")"
    sed -i -E "/^    ${system} = \{/,/^    \};/ s#hash = \"[^\"]+\";#hash = \"${hash}\";#" "$pkg_file"
done

cd "$repo_root"
nix build path:.#probe --no-link
trap - ERR
printf 'probe updated to %s\n' "$version"
