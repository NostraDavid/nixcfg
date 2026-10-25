#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
package="$(basename "$0" .sh)"
package="${package#update-}"
pkg_file="${repo_root}/pkgs/${package}/default.nix"
systems=(x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin)
tag_prefix=v

case "$package" in
agent-orchestrator)
    repo=OrchestratorInc/agent-orchestrator
    systems=(x86_64-linux x86_64-darwin aarch64-darwin)
    ;;
fixit) repo=eugene-babichenko/fixit ;;
beads) repo=gastownhall/beads ;;
bitbucket-cli) repo=avivsinai/bitbucket-cli ;;
dockerfile-roast) repo=immanuwell/dockerfile-roast ;;
emdash) repo=generalaction/emdash ;;
jsongrep) repo=micahkepe/jsongrep ;;
kandev) repo=kdlbs/kandev ;;
mdschema) repo=jackchuka/mdschema ;;
orca-ide) repo=stablyai/orca ;;
outlook-cli) repo=rvben/outlook-cli ;;
pandacode)
    repo=aicodeking/pandacode
    systems=(x86_64-linux aarch64-linux aarch64-darwin)
    ;;
paseo-desktop)
    repo=getpaseo/paseo
    systems=(x86_64-linux x86_64-darwin aarch64-darwin)
    ;;
rtk) repo=rtk-ai/rtk ;;
snip) repo=edouard-claude/snip ;;
superset)
    repo=superset-sh/superset
    systems=(x86_64-linux x86_64-darwin aarch64-darwin)
    tag_prefix=desktop-v
    ;;
*)
    echo "Unsupported package: $package" >&2
    exit 1
    ;;
esac

release="$(gh api "repos/${repo}/releases/latest")"
tag="$(jq -er '.tag_name' <<<"$release")"
version="${tag#"$tag_prefix"}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Unexpected release tag: $tag" >&2
    exit 1
}

backup="$(mktemp)"
cp "$pkg_file" "$backup"
trap 'cp "$backup" "$pkg_file"' ERR
trap 'rm -f "$backup"' EXIT

sed -i -E "s/version = \"[^\"]+\";/version = \"${version}\";/" "$pkg_file"
for system in "${systems[@]}"; do
    case "$system" in
    x86_64-linux)
        rust=x86_64-unknown-linux-musl
        roast=linux-x86_64
        go=linux_amd64
        bkt=linux_x86_64
        rtk_target=$rust
        ;;
    aarch64-linux)
        rust=aarch64-unknown-linux-musl
        roast=linux-arm64
        go=linux_arm64
        bkt=linux_arm64
        rtk_target=aarch64-unknown-linux-gnu
        ;;
    x86_64-darwin)
        rust=x86_64-apple-darwin
        roast=macos-x86_64
        go=darwin_amd64
        bkt=darwin_x86_64
        rtk_target=$rust
        ;;
    aarch64-darwin)
        rust=aarch64-apple-darwin
        roast=macos-arm64
        go=darwin_arm64
        bkt=darwin_arm64
        rtk_target=$rust
        ;;
    esac
    case "$package" in
    agent-orchestrator)
        case "$system" in
        x86_64-linux) asset=agent-orchestrator-linux-x64.AppImage ;;
        x86_64-darwin) asset=agent-orchestrator-darwin-x64.zip ;;
        aarch64-darwin) asset=agent-orchestrator-darwin-arm64.zip ;;
        esac
        ;;
    fixit) asset="fixit-v${version}-${rust}.tar.gz" ;;
    beads) asset="beads_${version}_${go}.tar.gz" ;;
    bitbucket-cli) asset="bkt_${version}_${bkt}.tar.gz" ;;
    dockerfile-roast) asset="droast-${roast}" ;;
    emdash)
        case "$system" in
        x86_64-linux) asset=emdash-x86_64.AppImage ;;
        aarch64-linux) asset=emdash-arm64.AppImage ;;
        x86_64-darwin) asset=emdash-x64.zip ;;
        aarch64-darwin) asset=emdash-arm64.zip ;;
        esac
        ;;
    jsongrep) asset="jsongrep-${version}-${rust}.tar.gz" ;;
    kandev)
        case "$system" in
        x86_64-linux) asset="kandev-desktop-linux-x64-Kandev_${version}_amd64.AppImage" ;;
        aarch64-linux) asset="kandev-desktop-linux-arm64-Kandev_${version}_aarch64.AppImage" ;;
        x86_64-darwin) asset=kandev-desktop-macos-x64-Kandev.app.tar.gz ;;
        aarch64-darwin) asset=kandev-desktop-macos-arm64-Kandev.app.tar.gz ;;
        esac
        ;;
    mdschema) asset="mdschema_${version}_${go}.tar.gz" ;;
    orca-ide)
        case "$system" in
        x86_64-linux) asset=orca-linux.AppImage ;;
        aarch64-linux) asset=orca-linux-arm64.AppImage ;;
        x86_64-darwin) asset="Orca-${version}-mac.zip" ;;
        aarch64-darwin) asset="Orca-${version}-arm64-mac.zip" ;;
        esac
        ;;
    outlook-cli) asset="outlook-v${version}-${rust}.tar.gz" ;;
    pandacode)
        case "$system" in
        x86_64-linux) asset=PandaCode-Linux-x86_64.AppImage ;;
        aarch64-linux) asset=PandaCode-Linux-aarch64.AppImage ;;
        aarch64-darwin) asset=PandaCode-macOS-arm64.app.tar.gz ;;
        esac
        ;;
    paseo-desktop)
        case "$system" in
        x86_64-linux) asset=Paseo-x86_64.AppImage ;;
        x86_64-darwin) asset="Paseo-${version}-x64.zip" ;;
        aarch64-darwin) asset="Paseo-${version}-arm64.zip" ;;
        esac
        ;;
    rtk) asset="rtk-${rtk_target}.tar.gz" ;;
    snip) asset="snip_${version}_${go}.tar.gz" ;;
    superset)
        case "$system" in
        x86_64-linux) asset="superset-${version}-x86_64.AppImage" ;;
        x86_64-darwin) asset="Superset-${version}-mac.zip" ;;
        aarch64-darwin) asset="Superset-${version}-arm64-mac.zip" ;;
        esac
        ;;
    esac
    digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest | select(startswith("sha256:")) | sub("^sha256:"; "")' <<<"$release")"
    hash="$(nix hash convert --hash-algo sha256 --to sri "$digest")"
    sed -i -E "/^    ${system} = \{/,/^    \};/ s#hash = \"[^\"]+\";#hash = \"${hash}\";#" "$pkg_file"
done

cd "$repo_root"
nix build ".#${package}" --no-link
trap - ERR
printf '%s updated to %s\n' "$package" "$version"
