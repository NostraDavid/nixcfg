#!/usr/bin/env bash
# Updates the pinned CPython 3.13 tiktoken wheels from PyPI.

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/tiktoken/default.nix"
cli_file="${repo_root}/pkgs/tiktoken/tiktoken.py"
release_json="$(curl -fsSL https://pypi.org/pypi/tiktoken/json)"
version="$(jq -er '.info.version' <<<"${release_json}")"

wheel_info() {
  local suffix="$1"
  jq -er --arg suffix "${suffix}" '
    first(.urls[] | select(.filename | endswith($suffix)))
    | [.url, .digests.sha256]
    | @tsv
  ' <<<"${release_json}"
}

read -r x86_url x86_digest < <(wheel_info "-cp313-cp313-manylinux_2_28_x86_64.whl")
read -r darwin_url darwin_digest < <(wheel_info "-cp313-cp313-macosx_11_0_arm64.whl")
x86_hash="$(nix hash convert --hash-algo sha256 --to sri "${x86_digest}")"
darwin_hash="$(nix hash convert --hash-algo sha256 --to sri "${darwin_digest}")"

original_pkg="$(cat "${pkg_file}")"
original_cli="$(cat "${cli_file}")"

current_field() {
  local system="$1"
  local field="$2"
  awk -v target_system="${system}" -v field="${field}" '
    index($0, target_system) { in_system = 1 }
    in_system && $1 == field { gsub(/[";]/, "", $3); print $3; exit }
  ' "${pkg_file}"
}

replace_system() {
  local system="$1"
  local new_url="$2"
  local new_hash="$3"
  local old_url old_hash
  old_url="$(current_field "${system}" url)"
  old_hash="$(current_field "${system}" hash)"
  sed -i "s|url = \"${old_url}\";|url = \"${new_url}\";|" "${pkg_file}"
  sed -i "s#hash = \"${old_hash}\";#hash = \"${new_hash}\";#" "${pkg_file}"
}

sed -i "0,/version = \"[^\"]*\";/s//version = \"${version}\";/" "${pkg_file}"
replace_system x86_64-linux "${x86_url}" "${x86_hash}"
replace_system aarch64-darwin "${darwin_url}" "${darwin_hash}"
sed -i "s/version=\"%(prog)s [^\"]*\"/version=\"%(prog)s ${version}\"/" "${cli_file}"

if [[ "$(cat "${pkg_file}")" == "${original_pkg}" && "$(cat "${cli_file}")" == "${original_cli}" ]]; then
  printf 'tiktoken is already at latest version %s\n' "${version}"
  exit 0
fi

printf 'Updating tiktoken to version %s\n' "${version}"
if ! nix build .#tiktoken --no-link; then
  printf '%s' "${original_pkg}" >"${pkg_file}"
  printf '%s' "${original_cli}" >"${cli_file}"
  echo 'Latest tiktoken release failed to build; restored the previous working package.' >&2
  exit 1
fi

echo 'tiktoken update complete.'
