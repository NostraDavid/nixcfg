#!/usr/bin/env bash
# Update only the main source; the Python dependencies have independent versions.
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/semble/default.nix"
version="$(git ls-remote --tags --refs https://github.com/MinishLab/semble.git |
    awk -F/ '$NF ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^v/, "", $NF); print $NF }' |
    sort -V | tail -n1)"
[[ -n "${version}" ]] || {
    echo 'Failed to determine latest semble release tag.' >&2
    exit 1
}
source_hash="$(nix store prefetch-file --json --unpack "https://github.com/MinishLab/semble/archive/refs/tags/v${version}.tar.gz" | jq -er '.hash')"
original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating semble to version %s\n' "${version}"
sed -i -E '/pname = "semble";/,/pyproject =/ s/version = "[^"]+";/version = "'"${version}"'";/' "${pkg_file}"
sed -i -E "/repo = \"semble\"/,/};/ s#hash = \"[^\"]+\";#hash = \"${source_hash}\";#" "${pkg_file}"
cd "${repo_root}"
nix build .#semble --no-link
trap - ERR
echo 'semble update complete.'
