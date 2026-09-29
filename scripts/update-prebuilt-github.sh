#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
package="$(basename "$0" .sh)"
package="${package#update-}"
pkg_file="${repo_root}/pkgs/${package}/default.nix"

case "$package" in
fixit) repo=eugene-babichenko/fixit ;;
dockerfile-roast) repo=immanuwell/dockerfile-roast ;;
jsongrep) repo=micahkepe/jsongrep ;;
mdschema) repo=jackchuka/mdschema ;;
*)
    echo "Unsupported package: $package" >&2
    exit 1
    ;;
esac

release="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")"
tag="$(jq -er '.tag_name' <<<"$release")"
version="${tag#v}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Unexpected release tag: $tag" >&2
    exit 1
}

backup="$(mktemp)"
cp "$pkg_file" "$backup"
trap 'cp "$backup" "$pkg_file"' ERR
trap 'rm -f "$backup"' EXIT

sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "$pkg_file"
for system in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    case "$system" in
    x86_64-linux)
        rust=x86_64-unknown-linux-musl
        roast=linux-x86_64
        go=linux_amd64
        ;;
    aarch64-linux)
        rust=aarch64-unknown-linux-musl
        roast=linux-arm64
        go=linux_arm64
        ;;
    x86_64-darwin)
        rust=x86_64-apple-darwin
        roast=macos-x86_64
        go=darwin_amd64
        ;;
    aarch64-darwin)
        rust=aarch64-apple-darwin
        roast=macos-arm64
        go=darwin_arm64
        ;;
    esac
    case "$package" in
    fixit) asset="fixit-v${version}-${rust}.tar.gz" ;;
    dockerfile-roast) asset="droast-${roast}" ;;
    jsongrep) asset="jsongrep-${version}-${rust}.tar.gz" ;;
    mdschema) asset="mdschema_${version}_${go}.tar.gz" ;;
    esac
    digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest | select(startswith("sha256:")) | sub("^sha256:"; "")' <<<"$release")"
    hash="$(nix hash convert --hash-algo sha256 --to sri "$digest")"
    sed -i -E "/^    ${system} = \{/,/^    \};/ s#hash = \"[^\"]+\";#hash = \"${hash}\";#" "$pkg_file"
done

cd "$repo_root"
nix build ".#${package}" --no-link
trap - ERR
printf '%s updated to %s\n' "$package" "$version"
