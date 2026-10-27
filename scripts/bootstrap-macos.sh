#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
    printf 'error: this script requires macOS\n' >&2
    exit 1
fi

if command -v nix >/dev/null 2>&1 || [[ -x /nix/var/nix/profiles/default/bin/nix ]]; then
    printf 'Nix is already installed. Open a new terminal if it is not on PATH.\n'
    exit 0
fi

installer=$(mktemp -t nix-bootstrap.XXXXXX)
trap 'rm -f "$installer"' EXIT
curl --proto '=https' --tlsv1.2 -sSfL https://nixos.org/nix/install -o "$installer"
NIX_FIRST_BUILD_UID=600 NIX_BUILD_GROUP_ID=600 sh "$installer" --daemon

printf '\nNix installed. Open a new terminal before applying nix-darwin.\n'
