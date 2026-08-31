#!/usr/bin/env bash
# Updates the lean-ctx Linux release archive.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/lean-ctx/default.nix"
current_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";$/\1/p' "${pkg_file}" | head -n1)"
version="$(git ls-remote --tags --refs 'https://github.com/yvgude/lean-ctx.git' |
    awk -F/ '$NF ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^v/, "", $NF); print $NF }' |
    sort -V |
    tail -n1)"

[[ -n "${version}" ]] || {
    echo 'Failed to determine the latest lean-ctx version.' >&2
    exit 1
}

if [[ "${version}" == "${current_version}" ]]; then
    printf 'lean-ctx is already at %s\n' "${version}"
    exit 0
fi

url="https://github.com/yvgude/lean-ctx/releases/download/v${version}/lean-ctx-x86_64-unknown-linux-musl.tar.gz"
source_hash="$(nix store prefetch-file --json "${url}" | jq -er '.hash')"
original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating lean-ctx to version %s\n' "${version}"
sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "${pkg_file}"
sed -i -E "/url = \"https:\/\/github\.com\/yvgude\/lean-ctx\/releases/ { n; s#hash = \"[^\"]+\";#hash = \"${source_hash}\";#; }" "${pkg_file}"

cd "${repo_root}"
echo 'Verifying nix build...'
nix build .#lean-ctx --no-link
trap - ERR
echo 'lean-ctx update complete.'
