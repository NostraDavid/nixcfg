#!/usr/bin/env bash
# Updates the versioned Linux ChatGPT .deb from OpenAI's APT repository.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/chatgpt/default.nix"
version="${1:-}"
packages_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages"

if [[ -z "${version}" ]]; then
    version="$(curl -fsSL "${packages_url}" | awk '
        /^Package: chatgpt$/ { in_package = 1; next }
        in_package && /^Version: / { print substr($0, 10); exit }
        in_package && /^$/ { exit }
    ')"
fi

[[ -n "${version}" ]] || {
    echo 'Failed to determine the latest ChatGPT version.' >&2
    exit 1
}

url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb"
source_hash="$(nix store prefetch-file --json "${url}" | jq -er '.hash')"

original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating chatgpt to version %s\n' "${version}"
sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "${pkg_file}"
sed -i -E "/url = \"https:\/\/persistent\.oaistatic\.com\/.*chatgpt_/ { n; s#hash = \"[^\"]+\";#hash = \"${source_hash}\";#; }" "${pkg_file}"

cd "${repo_root}"
echo 'Verifying nix build...'
nix build .#chatgpt --no-link
trap - ERR
echo 'chatgpt update complete.'
