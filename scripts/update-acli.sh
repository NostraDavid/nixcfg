#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
pkg_file="$repo_root/pkgs/acli/default.nix"
temp_dir="$(mktemp -d)"
cp "$pkg_file" "$temp_dir/default.nix"
success=0
cleanup() {
    if ((!success)); then
        cp "$temp_dir/default.nix" "$pkg_file"
    fi
    rm -rf "$temp_dir"
}
trap cleanup EXIT

curl -fsSL https://acli.atlassian.com/linux/latest/acli_linux_amd64.tar.gz -o "$temp_dir/acli.tar.gz"
version="$(tar -tzf "$temp_dir/acli.tar.gz" |
    sed -nE 's#^acli_([0-9]+\.[0-9]+\.[0-9]+-stable)_linux_amd64/acli$#\1#p' |
    sort -u)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-stable$ ]] || {
    echo "Unable to determine the latest Atlassian CLI version" >&2
    exit 1
}

sed -i -E "s/version = \"[^\"]+\";/version = \"$version\";/" "$pkg_file"
for system in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    case "$system" in
    x86_64-linux) platform=linux arch=amd64 ;;
    aarch64-linux) platform=linux arch=arm64 ;;
    x86_64-darwin) platform=darwin arch=amd64 ;;
    aarch64-darwin) platform=darwin arch=arm64 ;;
    esac
    archive="$temp_dir/$system.tar.gz"
    if [[ "$system" == x86_64-linux ]]; then
        archive="$temp_dir/acli.tar.gz"
    else
        curl -fsSL "https://acli.atlassian.com/$platform/$version/acli_${version}_${platform}_${arch}.tar.gz" -o "$archive"
    fi
    hash="$(nix hash file --type sha256 --sri "$archive")"
    sed -i -E "/^    \"$system\" = \{/,/^    \};/ s#hash = \"[^\"]+\";#hash = \"$hash\";#" "$pkg_file"
done

cd "$repo_root"
nix build path:.#acli --no-link --no-write-lock-file
success=1
printf 'acli updated to %s\n' "$version"
