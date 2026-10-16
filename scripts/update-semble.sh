#!/usr/bin/env bash
# Update only the main source; the Python dependencies have independent versions.
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/semble/default.nix"
metadata="$(curl -fsSL https://pypi.org/pypi/semble/json)"
version="$(jq -er '.info.version' <<<"${metadata}")"
source_url="$(jq -er '.urls[] | select(.packagetype == "sdist" and .yanked != true) | .url' <<<"${metadata}")"
source_hash="$(nix store prefetch-file --json "${source_url}" | jq -er '.hash')"
original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating semble to version %s\n' "${version}"
sed -i -E '/pname = "semble";/,/pyproject =/ s/version = "[^"]+";/version = "'"${version}"'";/' "${pkg_file}"
sed -i -E "/pname = \"semble\";/,/build-system =/ s#hash = \"[^\"]+\";#hash = \"${source_hash}\";#" "${pkg_file}"
cd "${repo_root}"
nix build .#semble --no-link
trap - ERR
echo 'semble update complete.'
