#!/usr/bin/env bash
# Updates the source distribution and Cargo vendor hash from PyPI.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/gigatoken/default.nix"
cli_file="${repo_root}/pkgs/gigatoken/gigatoken.py"
version="${1:-}"

release_json="$(curl -fsSL https://pypi.org/pypi/gigatoken/json)"
if [[ -z "${version}" ]]; then
    version="$(jq -er '.info.version' <<<"${release_json}")"
fi

filename="gigatoken-${version}.tar.gz"
read -r asset_url asset_digest < <(
    if [[ -n "${1:-}" ]]; then
        curl -fsSL "https://pypi.org/pypi/gigatoken/${version}/json"
    else
        printf '%s' "${release_json}"
    fi |
        jq -er --arg filename "${filename}" \
            '.urls[] | select(.filename == $filename) | [.url, .digests.sha256] | @tsv'
)
source_hash="$(nix hash convert --hash-algo sha256 --to sri "${asset_digest}")"
current_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";$/\1/p' "${pkg_file}" | head -n1)"
current_cli_version="$(sed -n 's/.*version="%(prog)s \([^"]*\)".*/\1/p' "${cli_file}" | head -n1)"

if [[ "${version}" == "${current_version}" && "${version}" == "${current_cli_version}" ]] &&
    grep -Fq "url = \"${asset_url}\";" "${pkg_file}" &&
    ! grep -Fq 'hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";' "${pkg_file}"; then
    printf 'gigatoken is already at %s\n' "${version}"
    exit 0
fi

original_pkg="$(cat "${pkg_file}")"
original_cli="$(cat "${cli_file}")"
restore() {
    printf '%s\n' "${original_pkg}" >"${pkg_file}"
    printf '%s\n' "${original_cli}" >"${cli_file}"
}
trap restore ERR

replace_cargo_hash() {
    local new_hash="$1"
    local temporary_file

    temporary_file="$(mktemp)"
    awk -v new_hash="${new_hash}" '
      /cargoDeps = rustPlatform.fetchCargoVendor/ { in_cargo = 1 }
      in_cargo && /hash =/ {
        sub(/hash = "[^"]+";/, "hash = \"" new_hash "\";")
        in_cargo = 0
      }
      { print }
    ' "${pkg_file}" >"${temporary_file}"
    mv "${temporary_file}" "${pkg_file}"
}

printf 'Updating gigatoken to version %s\n' "${version}"
sed -i "0,/version = \".*\";/s//version = \"${version}\";/" "${pkg_file}"
sed -i -E "/url = \".*gigatoken-.*\.tar\.gz\";/ { n; s#hash = \".*\";#hash = \"${source_hash}\";#; }" "${pkg_file}"
sed -i -E "s#url = \"https://files.pythonhosted.org/[^\"]*/gigatoken-[^\"]+\.tar\.gz\";#url = \"${asset_url}\";#" "${pkg_file}"
sed -i -E "s/version=\"%(prog)s [^\"]*\"/version=\"%(prog)s ${version}\"/" "${cli_file}"

replace_cargo_hash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
build_log="$(mktemp)"
if nix build .#gigatoken --no-link >"${build_log}" 2>&1; then
    echo 'Unexpectedly built with a fake Cargo hash.' >&2
    cat "${build_log}" >&2
    rm -f "${build_log}"
    restore
    exit 1
fi

cargo_hash="$(sed -n 's/.*got:[[:space:]]*\(sha256-[^[:space:]]*\).*/\1/p' "${build_log}" | tail -n1)"
if [[ -z "${cargo_hash}" ]]; then
    cat "${build_log}" >&2
    rm -f "${build_log}"
    restore
    exit 1
fi

replace_cargo_hash "${cargo_hash}"
echo 'Verifying nix build...'
if ! nix build .#gigatoken --no-link >>"${build_log}" 2>&1; then
    cat "${build_log}" >&2
    rm -f "${build_log}"
    restore
    exit 1
fi
rm -f "${build_log}"
trap - ERR
echo 'gigatoken update complete.'
