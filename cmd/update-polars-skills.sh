#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

version="$(git ls-remote --tags --refs 'https://github.com/polars-inc/skills.git' |
    awk -F/ '$NF ~ /^v0\.[0-9]+\.[0-9]+$/ { sub(/^v/, "", $NF); print $NF }' |
    sort -V |
    tail -n1)"

if [[ -z "${version}" ]]; then
    echo 'Failed to determine latest Polars skills v0.x.x tag.' >&2
    exit 1
fi

printf 'Updating polars-skills to version %s\n' "${version}"
sed -i "s#github:polars-inc/skills[^\"]*#github:polars-inc/skills/v${version}#" flake.nix
sed -i "s/version = \".*\";/version = \"${version}\";/" pkgs/polars-skills/default.nix

exec "${repo_root}/cmd/update-flake-package.sh" polars-skills polars-skills
