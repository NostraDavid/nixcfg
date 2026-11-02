#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
pkg_file="$repo_root/pkgs/elastic-cli/default.nix"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -p "$pkg_file" "$tmp/original"
cd "$repo_root"

status=0
nix run nixpkgs#nix-update -- -F elastic-cli || status=$?
cp -p "$pkg_file" "$tmp/updated"
if ((status == 0)); then
    nix build path:.#elastic-cli --no-link || status=$?
fi
if ((status != 0)); then
    # Reverse only our update; never replace concurrent edits with the backup.
    cp -p "$pkg_file" "$tmp/current"
    if git merge-file -p "$tmp/current" "$tmp/updated" "$tmp/original" >"$tmp/restored" && cmp -s "$pkg_file" "$tmp/current"; then
        cat "$tmp/restored" >"$pkg_file"
    else
        echo 'Concurrent changes conflict with rollback; package left untouched.' >&2
    fi
    exit "$status"
fi
echo 'elastic-cli update complete.'
