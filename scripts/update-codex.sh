#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
pkg=pkgs/codex/default.nix
backup=$(mktemp)
cp "$pkg" "$backup"
trap 'cp "$backup" "$pkg"' ERR
trap 'rm -f "$backup"' EXIT

nix run nixpkgs#nix-update -- -F codex --use-github-releases --version-regex '^rust-v(\d+\.\d+\.\d+)$'

version=$(nix eval --raw .#codex.version)
checksum=$(curl -fsSL "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package_SHA256SUMS" |
    awk '$2 == "codex-package-aarch64-apple-darwin.tar.gz" { print $1 }')
test -n "$checksum"
hash=$(nix hash convert --to sri --hash-algo sha256 "$checksum")
sed -i "/aarch64-darwin = {/,/};/ s#hash = \"[^\"]*\";#hash = \"${hash}\";#" "$pkg"

nix build .#codex --no-link
