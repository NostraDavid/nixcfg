#!/usr/bin/env bash
# Updates the pinned Linux headroom-ai wheel from PyPI.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/headroom/default.nix"
version="${1:-}"

release_json="$(curl -fsSL https://pypi.org/pypi/headroom-ai/json)"
if [[ -z "${version}" ]]; then
    version="$(jq -er '.info.version' <<<"${release_json}")"
fi

filename="headroom_ai-${version}-cp310-abi3-manylinux_2_28_x86_64.whl"
read -r asset_url asset_digest < <(
    if [[ -n "${1:-}" ]]; then
        curl -fsSL "https://pypi.org/pypi/headroom-ai/${version}/json"
    else
        printf '%s' "${release_json}"
    fi |
        jq -er --arg filename "${filename}" \
            '.urls[] | select(.filename == $filename) | [.url, .digests.sha256] | @tsv'
)
source_hash="$(nix hash convert --hash-algo sha256 --to sri "${asset_digest}")"

original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating headroom to version %s\n' "${version}"
sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i -E "/url = \".*headroom_ai-/ { n; s#hash = \".*\";#hash = \"${source_hash}\";#; }" "${pkg_file}"
sed -i -E "s#url = \"https://files.pythonhosted.org/[^\"]*/headroom_ai-[^\"]+\";#url = \"${asset_url}\";#" "${pkg_file}"

echo 'Verifying nix build...'
nix build .#headroom --no-link
trap - ERR
echo 'headroom update complete.'
