#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/cmux-tui/default.nix"
manifest="$(curl -fsSL https://files.cmux.com/cmux-tui/latest/manifest.json)"
rev="$(jq -er '.commit | select(test("^[0-9a-f]{40}$"))' <<<"${manifest}")"
built_at="$(jq -er '.builtAt' <<<"${manifest}")"
release_date="$(date -u -d "${built_at}" +%Y-%m-%d)"

backup="$(mktemp)"
cp "${pkg_file}" "${backup}"
trap 'cp "${backup}" "${pkg_file}"' ERR
trap 'rm -f "${backup}"' EXIT

printf 'Updating cmux-tui to unstable-%s (%s)\n' "${release_date}" "${rev}"
sed -i -E "s/rev = \"[^\"]+\";/rev = \"${rev}\";/; s/(version = \"[^\"]*-unstable-)[^\"]+/\1${release_date}/" "${pkg_file}"
for system in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    case "${system}" in
    x86_64-linux) target=x86_64-unknown-linux-musl ;;
    aarch64-linux) target=aarch64-unknown-linux-musl ;;
    x86_64-darwin) target=x86_64-apple-darwin ;;
    aarch64-darwin) target=aarch64-apple-darwin ;;
    esac
    digest="$(jq -er --arg name "cmux-tui-${target}" '.binaries[$name] | select(test("^[0-9a-f]{64}$"))' <<<"${manifest}")"
    hash="$(nix hash convert --hash-algo sha256 --to sri "${digest}")"
    sed -i -E "/^    ${system} = \{/,/^    \};/ s#hash = \"[^\"]+\";#hash = \"${hash}\";#" "${pkg_file}"
done

cd "${repo_root}"
echo 'Verifying nix build...'
nix build .#cmux-tui --no-link
trap - ERR
echo 'cmux-tui update complete.'
