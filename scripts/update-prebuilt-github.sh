#!/usr/bin/env bash
set -euo pipefail

package="$(basename "$0" .sh)"
package="${package#update-}"
if (($#)) && [[ $# != 1 || $1 != --latest-version ]]; then
    printf 'Usage: %s [--latest-version]\n' "$0" >&2
    exit 2
fi
systems=(x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin)

case "$package" in
bitbucket-cli) repo=avivsinai/bitbucket-cli ;;
dockerfile-roast) repo=immanuwell/dockerfile-roast ;;
pandacode)
    repo=aicodeking/pandacode
    systems=(x86_64-linux aarch64-linux aarch64-darwin)
    ;;
*)
    echo "Unsupported package: $package" >&2
    exit 1
    ;;
esac

release="$(gh api "repos/${repo}/releases/latest")"
tag="$(jq -er '.tag_name' <<<"$release")"
version="${tag#v}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Unexpected release tag: $tag" >&2
    exit 1
}
if [[ ${1:-} == --latest-version ]]; then
    printf '%s\n' "$version"
    exit 0
fi

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
pkg_file="${repo_root}/pkgs/${package}/default.nix"
edits=(-e "s/version = \"[^\"]+\";/version = \"${version}\";/")
for system in "${systems[@]}"; do
    case "$system" in
    x86_64-linux)
        roast=linux-x86_64
        bkt=linux_x86_64
        ;;
    aarch64-linux)
        roast=linux-arm64
        bkt=linux_arm64
        ;;
    x86_64-darwin)
        roast=macos-x86_64
        bkt=darwin_x86_64
        ;;
    aarch64-darwin)
        roast=macos-arm64
        bkt=darwin_arm64
        ;;
    esac
    case "$package" in
    bitbucket-cli) asset="bkt_${version}_${bkt}.tar.gz" ;;
    dockerfile-roast) asset="droast-${roast}" ;;
    pandacode)
        case "$system" in
        x86_64-linux) asset=PandaCode-Linux-x86_64.AppImage ;;
        aarch64-linux) asset=PandaCode-Linux-aarch64.AppImage ;;
        aarch64-darwin) asset=PandaCode-macOS-arm64.app.tar.gz ;;
        esac
        ;;
    esac
    digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest | select(startswith("sha256:")) | sub("^sha256:"; "")' <<<"$release")"
    hash="$(nix hash convert --hash-algo sha256 --to sri "$digest")"
    edits+=(-e "/^    ${system} = \{/,/^    \};/ s#hash = \"[^\"]+\";#hash = \"${hash}\";#")
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
sed -E "${edits[@]}" "$pkg_file" >"$tmp/updated"
if [[ ${NIXCFG_SKIP_UNCHANGED:-0} == 1 ]] && cmp -s "$tmp/updated" "$pkg_file"; then
    printf '%s %s release assets unchanged.\n' "$package" "$version"
    exit 0
fi
cp "$pkg_file" "$tmp/original"
trap 'cp "$tmp/original" "$pkg_file"' ERR
cp "$tmp/updated" "$pkg_file"
cd "$repo_root"
nix build ".#${package}" --no-link
trap - ERR
printf '%s updated to %s\n' "$package" "$version"
