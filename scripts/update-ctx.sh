#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "$repo_root"
pkg_file=pkgs/ctx/default.nix
version="$(git ls-remote --tags --refs https://github.com/ctxrs/ctx.git |
    awk -F/ '$NF ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^v/, "", $NF); print $NF }' |
    sort -V | tail -n1)"
[[ -n "$version" ]] || {
    echo 'No CTX version tag found.' >&2
    exit 1
}

for asset in ctx-linux-x64 ctx-macos-arm64 ctx-macos-x64; do
    hash="$(nix store prefetch-file --json "https://github.com/ctxrs/ctx/releases/download/v$version/$asset" | jq -er .hash)"
    hashes+=("$asset:$hash")
done
skill_hash="$(nix store prefetch-file --json --unpack "https://github.com/ctxrs/ctx/archive/refs/tags/v$version.tar.gz" | jq -er .hash)"
backup="$(mktemp)"
cp "$pkg_file" "$backup"
trap 'rm -f "$backup"' EXIT
trap 'cp "$backup" "$pkg_file"' ERR

sed -i -E "s/version = \"[^\"]+\";/version = \"$version\";/" "$pkg_file"
for entry in "${hashes[@]}"; do
    asset="${entry%%:*}"
    hash="${entry#*:}"
    sed -i -E "/asset = \"$asset\"/ { n; s#hash = \"[^\"]+\";#hash = \"$hash\";#; }" "$pkg_file"
done
sed -i -E "/tag = / { n; s#hash = \"[^\"]+\";#hash = \"$skill_hash\";#; }" "$pkg_file"
nix build .#ctx --no-link
trap - ERR
printf 'CTX CLI and skill updated to %s\n' "$version"
