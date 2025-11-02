#!/usr/bin/env bash
# Updates pkgs/nanocoder/default.nix to the desired upstream release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
  version="$(npm view @nanocollective/nanocoder version)"
fi

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
default_nix="${repo_root}/pkgs/nanocoder/default.nix"

printf 'Updating nanocoder to version %s\n' "${version}"

prefetch_json="$(nix store prefetch-file --json --unpack "https://registry.npmjs.org/@nanocollective/nanocoder/-/nanocoder-${version}.tgz")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"

sed -i "0,/version = \".*\";/s#version = \".*\";#version = \"${version}\";#" "${default_nix}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${default_nix}"

echo 'Verifying nix build...'
nix build .#nanocoder --no-link

echo 'nanocoder update complete.'
