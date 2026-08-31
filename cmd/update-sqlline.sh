#!/usr/bin/env bash
# SQLLine is supplied by the locked nixpkgs input and wrapped locally.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
system="${NIX_SYSTEM:-$(nix eval --impure --raw --expr 'builtins.currentSystem')}"
version="$(nix eval --raw "path:${repo_root}#packages.${system}.sqlline.version")"
printf 'sqlline is provided by nixpkgs at %s\n' "${version}"
