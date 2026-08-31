#!/usr/bin/env bash
# Updates a package supplied by a locked flake input.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <flake-input> <package>" >&2
    exit 1
fi

input="$1"
package="$2"
repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

printf 'Updating flake input: %s\n' "${input}"
nix flake update --option http-connections 1 "${input}"

echo 'Verifying nix build...'
nix build ".#${package}" --no-link
printf '%s update complete.\n' "${package}"
