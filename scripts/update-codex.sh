#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
pkg=pkgs/codex/default.nix
release="$(gh api repos/openai/codex/releases/latest)"
tag="$(jq -er '.tag_name' <<<"$release")"
version="${tag#rust-v}"
[[ "$tag" == "rust-v${version}" && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Unexpected Codex release tag: $tag" >&2
    exit 1
}
backup=$(mktemp)
cp "$pkg" "$backup"
trap 'cp "$backup" "$pkg"' ERR
trap 'rm -f "$backup"' EXIT

sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "$pkg"
for system in x86_64-linux aarch64-darwin; do
    case "$system" in
    x86_64-linux) target=x86_64-unknown-linux-musl ;;
    aarch64-darwin) target=aarch64-apple-darwin ;;
    esac
    digest="$(jq -er --arg name "codex-package-${target}.tar.gz" \
        '.assets[] | select(.name == $name) | .digest | select(test("^sha256:[0-9a-f]{64}$")) | sub("^sha256:"; "")' <<<"$release")"
    hash=$(nix hash convert --to sri --hash-algo sha256 "$digest")
    sed -i "/${system} = {/,/};/ s#hash = \"[^\"]*\";#hash = \"${hash}\";#" "$pkg"
done

nix build .#codex --no-link
trap - ERR
printf 'codex updated to %s\n' "$version"
