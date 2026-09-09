#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

version="$(git ls-remote --tags --refs 'https://github.com/DietrichGebert/ponytail.git' |
    awk -F/ '$NF ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^v/, "", $NF); print $NF }' |
    sort -V |
    tail -n1)"

if [[ -z "${version}" ]]; then
    echo 'Failed to determine latest Ponytail skills version tag.' >&2
    exit 1
fi

printf 'Updating ponytail-skills to version %s\n' "${version}"
sed -i "s#github:DietrichGebert/ponytail[^\"]*#github:DietrichGebert/ponytail/v${version}#" flake.nix
sed -i "s/version = \".*\";/version = \"${version}\";/" pkgs/ponytail-skills/default.nix

exec "${repo_root}/cmd/update-flake-package.sh" ponytail-skills ponytail-skills
