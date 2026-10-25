#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
pkg_dir="$repo_root/pkgs/paperclip"
tmp="$(mktemp -d)"
cp "$pkg_dir/default.nix" "$tmp/default.nix"
cp "$pkg_dir/package-lock.json" "$tmp/package-lock.json"
restore() {
    cp "$tmp/default.nix" "$pkg_dir/default.nix"
    cp "$tmp/package-lock.json" "$pkg_dir/package-lock.json"
}
trap restore ERR
trap 'rm -rf "$tmp"' EXIT

nix run nixpkgs#nix-update -- -F paperclip --src-only
src="$(nix build .#paperclip.src --no-link --print-out-paths)"
node="$(nix build .#paperclip.nodejs --no-link --print-out-paths)"
overrides="$(nix eval --json .#paperclip.npmOverrides)"
mkdir "$tmp/source"
# nix-update generates locks before postPatch, so apply the package's overrides here.
tar -xOf "$src" package/package.json |
    jq --argjson overrides "$overrides" '.overrides = $overrides' >"$tmp/source/package.json"
cp "$pkg_dir/package-lock.json" "$tmp/source/package-lock.json"
"$node/bin/npm" install --package-lock-only --ignore-scripts --no-audit --no-fund \
    --prefix "$tmp/source" --cache "$tmp/npm-cache"
cp "$tmp/source/package-lock.json" "$pkg_dir/package-lock.json"
nix run nixpkgs#nix-update -- -F paperclip --version=skip
nix build .#paperclip --no-link

trap - ERR
echo 'paperclip update complete.'
