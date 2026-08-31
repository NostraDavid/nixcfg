#!/usr/bin/env bash
# Updates a package pinned to the current HEAD of a GitHub repository.

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <package> <owner> <repository>" >&2
    exit 2
fi

package="$1"
owner="$2"
repository="$3"
repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/${package}/default.nix"
current_rev="$(awk -v repository="${repository}" '
    $0 ~ "repo = \"" repository "\"" { in_source = 1 }
    in_source && /rev = "[0-9a-f]{40}";/ {
        match($0, /"[0-9a-f]{40}"/)
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
    }
' "${pkg_file}")"
latest_rev="$(git ls-remote "https://github.com/${owner}/${repository}.git" HEAD | awk '{print $1}')"

[[ -n "${current_rev}" && -n "${latest_rev}" ]] || {
    echo "Failed to determine the ${package} Git revision." >&2
    exit 1
}

if [[ "${latest_rev}" == "${current_rev}" ]]; then
    printf '%s is already at the latest Git revision %s\n' "${package}" "${current_rev:0:12}"
    exit 0
fi

source_hash="$(nix store prefetch-file --json --unpack "https://github.com/${owner}/${repository}/archive/${latest_rev}.tar.gz" | jq -er '.hash')"
version="unstable-$(date -u +%Y-%m-%d)"
original_pkg="$(cat "${pkg_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
}
trap restore ERR

printf 'Updating %s to %s (%s)\n' "${package}" "${version}" "${latest_rev:0:12}"
sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "${pkg_file}"
sed -i -E "/repo = \"${repository}\"/,/};/ { s#rev = \"[^\"]+\";#rev = \"${latest_rev}\";#; s#hash = \"[^\"]+\";#hash = \"${source_hash}\";#; }" "${pkg_file}"

cd "${repo_root}"
echo 'Verifying nix build...'
nix build ".#${package}" --no-link
trap - ERR
echo "${package} update complete."
