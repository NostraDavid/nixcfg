#!/usr/bin/env bash
set -euo pipefail

root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
package="$(basename "$0" .sh)"
package="${package#update-}"
case "$package" in
herdr-app) kind=app ;;
herdr-core) kind=core ;;
*)
    echo "Unsupported package: $package" >&2
    exit 1
    ;;
esac
file="$root/pkgs/$package/default.nix"
manifest="$(curl -fsSL "https://releases.herdr.dev/$kind/latest.json")"
version="$(jq -er '.version | select(type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$manifest")"
systems=(x86_64-linux aarch64-linux aarch64-darwin)
targets=(linux-x86_64 linux-aarch64 macos-aarch64)
hashes=()
for target in "${targets[@]}"; do
    url="https://releases.herdr.dev/$kind/$version/$package-$target.tar.gz"
    digest="$(jq -er --arg target "$target" --arg url "$url" '.targets[$target] | select(.url == $url) | .sha256 | select(type == "string" and test("^[0-9a-f]{64}$"))' <<<"$manifest")"
    hashes+=("$(nix hash convert --hash-algo sha256 --to sri "$digest")")
done

backup="$(mktemp)"
updated="$(mktemp)"
cp "$file" "$backup"
trap 'rm -f "$backup" "$updated"' EXIT
sed -i -E "s/version = \"[^\"]+\";/version = \"$version\";/" "$file"
for i in "${!systems[@]}"; do
    sed -i -E "/^    ${systems[$i]} = \{/,/^    \};/ s#hash = \"[^\"]+\";#hash = \"${hashes[$i]}\";#" "$file"
done
cp "$file" "$updated"
rollback() {
    if cmp -s "$updated" "$file"; then
        cp "$backup" "$file"
    else
        printf 'Not rolling back %s: it changed during the build; preserve and review its contents.\n' "$file" >&2
    fi
}
trap rollback ERR
cd "$root"
nix build ".#$package" --no-link
trap - ERR
printf '%s updated to %s\n' "$package" "$version"
