#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
cd "$repo_root"
cli=pkgs/opencode-v2/default.nix
desktop=pkgs/opencode-v2-desktop/default.nix
targets=(path:.#opencode-v2)
if [[ ${NIXCFG_BULK_HOST:-} != wodan || ${0##*/} == update-opencode-v2-desktop.sh ]]; then
    targets+=(path:.#opencode-v2-desktop)
fi
version=''
dry_run=0
for argument in "$@"; do
    case "$argument" in
    --dry-run) dry_run=1 ;;
    -h | --help)
        echo 'Usage: scripts/update-opencode-v2.sh [2.x.y] [--dry-run]'
        exit 0
        ;;
    *)
        if [[ -n "$version" || "$argument" == -* ]]; then
            echo "Unexpected argument: $argument" >&2
            exit 2
        fi
        version="$argument"
        ;;
    esac
done
if [[ -z "$version" ]]; then
    release=$(curl -fsSL https://opencode.ai/update/api/latest/cli/npm)
    version=$(jq -er 'select(.metadata.package == "@opencode/cli") | .version | strings' <<<"$release") || {
        echo 'Unexpected OpenCode CLI release metadata' >&2
        exit 1
    }
fi
[[ "$version" =~ ^2\.[0-9]+\.[0-9]+$ ]] || {
    echo "Expected a stable OpenCode 2.x version, got: $version" >&2
    exit 1
}

temporary=$(mktemp -d)
success=0
cleanup() {
    if [[ "$success" == 0 && -f "$temporary/cli.original" ]]; then
        cp "$temporary/cli.original" "$cli"
        if [[ -f "$temporary/desktop.original" ]]; then cp "$temporary/desktop.original" "$desktop"; fi
    fi
    rm -rf "$temporary"
}
trap cleanup EXIT
cp "$cli" "$temporary/cli.next"
sed -i -E "s/version = \"[^\"]+\";/version = \"$version\";/" "$temporary/cli.next"
for system in x86_64-linux aarch64-linux aarch64-darwin x86_64-darwin; do
    target=$(sed -n "/$system = {/,/};/s/.*target = \"\([^\"]*\)\";.*/\1/p" "$cli")
    [[ "$target" =~ ^(linux|darwin)-(x64|arm64)(-baseline)?$ ]] || {
        echo "Invalid target for $system: $target" >&2
        exit 1
    }
    metadata=$(curl -fsSL "https://registry.npmjs.org/@opencode%2fcli-$target/$version")
    hash=$(jq -er --arg name "@opencode/cli-$target" --arg version "$version" \
        'select(.name == $name and .version == $version) | .dist.integrity | strings | select(test("^sha512-[A-Za-z0-9+/]{86}==$"))' <<<"$metadata") || {
        echo "Missing or invalid npm integrity metadata for $target at $version" >&2
        exit 1
    }
    sed -i "/$system = {/,/};/s#hash = \"[^\"]*\";#hash = \"$hash\";#" "$temporary/cli.next"
done
if ((${#targets[@]} == 2)); then
    hash=$(nix store prefetch-file --json "https://opencode.ai/files/bin/$version/opencode-desktop-linux-x86_64.AppImage" |
        jq -er '.hash | strings | select(test("^sha256-[A-Za-z0-9+/]{43}=$"))')
    sed -E -e "s/version = \"[^\"]+\";/version = \"$version\";/" -e "s#hash = \"[^\"]*\";#hash = \"$hash\";#" "$desktop" >"$temporary/desktop.next"
fi

printf 'OpenCode target version: %s (%s)\n' "$version" "${targets[*]}"
if [[ "$dry_run" == 1 ]]; then
    echo 'Dry run: package definitions unchanged; no builds performed.'
    exit 0
fi
if cmp -s "$cli" "$temporary/cli.next" && { [[ ! -f "$temporary/desktop.next" ]] || cmp -s "$desktop" "$temporary/desktop.next"; }; then
    echo 'No changes detected, OpenCode v2 is already up to date.'
    exit 0
fi
cp "$cli" "$temporary/cli.original"
if [[ -f "$temporary/desktop.next" ]]; then
    cp "$desktop" "$temporary/desktop.original"
    cp "$temporary/desktop.next" "$desktop"
fi
cp "$temporary/cli.next" "$cli"
nix build "${targets[@]}" --no-link --no-write-lock-file
success=1
echo 'OpenCode v2 update complete.'
