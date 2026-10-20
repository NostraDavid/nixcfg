#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
nix eval --json "$root#packages.x86_64-linux" \
    --apply 'packages: builtins.mapAttrs (_: package: package.drvPath) packages' |
    jq -e 'has("codex") and (has("alt-tab-macos") | not) and (has("karabiner-elements-installer") | not)' >/dev/null

echo 'Linux package exports evaluate without Darwin-only packages.'
