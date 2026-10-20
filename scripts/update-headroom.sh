#!/usr/bin/env bash
# Updates the pinned Linux and macOS ARM64 headroom-ai wheels from PyPI.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/headroom/default.nix"
version="${1:-}"

release_json="$(curl -fsSL https://pypi.org/pypi/headroom-ai/json)"
if [[ -z "${version}" ]]; then
    version="$(jq -er '.info.version' <<<"${release_json}")"
fi

if [[ -n "${1:-}" ]]; then
    release_json="$(curl -fsSL "https://pypi.org/pypi/headroom-ai/${version}/json")"
fi
declare -A asset_urls source_hashes
for platform in manylinux_2_28_x86_64 macosx_11_0_arm64; do
    filename="headroom_ai-${version}-cp310-abi3-${platform}.whl"
    read -r asset_url asset_digest < <(
        jq -er --arg filename "${filename}" \
            '.urls[] | select(.filename == $filename and .yanked != true) | [.url, .digests.sha256] | @tsv' <<<"${release_json}"
    )
    asset_urls[$platform]="$asset_url"
    source_hashes[$platform]="$(nix hash convert --hash-algo sha256 --to sri "${asset_digest}")"
done

original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating headroom to version %s\n' "${version}"
sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
for platform in manylinux_2_28_x86_64 macosx_11_0_arm64; do
    sed -i -E "/url = \".*headroom_ai-.*-${platform}\\.whl/ { n; s#hash = \".*\";#hash = \"${source_hashes[$platform]}\";#; }" "${pkg_file}"
    sed -i -E "s#url = \"https://files.pythonhosted.org/[^\"]*/headroom_ai-[^\"]+-${platform}\\.whl\";#url = \"${asset_urls[$platform]}\";#" "${pkg_file}"
done

echo 'Verifying nix build...'
nix build .#headroom --no-link
trap - ERR
echo 'headroom update complete.'
