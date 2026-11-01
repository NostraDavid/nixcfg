#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
pkg_file="$repo_root/pkgs/twg/default.nix"
tmp="$(mktemp -d)"
staged=''
trap 'rm -rf "$tmp"; if [[ -n "$staged" ]]; then rm -f "$staged"; fi' EXIT
base=https://teamwork-graph.atlassian.com/cli
cp -p "$pkg_file" "$tmp/original"

manifest="$(curl -fsSL "$base/manifest.json")"
version="$(jq -er 'select(.channel == "stable") | .version | select(type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$manifest")"

for asset in linux-x64 darwin-arm64; do
    curl -fsSL "$base/twg-$asset-v$version" >"$tmp/$asset"
    [[ -s "$tmp/$asset" ]] || {
        echo "Empty $asset download" >&2
        exit 1
    }
done
linux_hash="$(nix hash file --type sha256 --sri "$tmp/linux-x64")"
darwin_hash="$(nix hash file --type sha256 --sri "$tmp/darwin-arm64")"

python3 - "$tmp/original" "$tmp/default.nix" "$version" "$linux_hash" "$darwin_hash" <<'PY'
import re
import sys
from pathlib import Path

source, target, version, linux_hash, darwin_hash = sys.argv[1:]
text = Path(source).read_text()
text, count = re.subn(r'(?m)^(  version = ")[^"]+(";)$', rf'\g<1>{version}\2', text)
if count != 1:
    raise SystemExit("Expected exactly one package version")
for system, digest in (("x86_64-linux", linux_hash), ("aarch64-darwin", darwin_hash)):
    pattern = rf'(?ms)(^    {system} = \{{\n.*?^      hash = ")[^"]+(";\n    \}};)'
    text, count = re.subn(pattern, rf'\g<1>{digest}\2', text)
    if count != 1:
        raise SystemExit(f"Expected exactly one hash for {system}")
Path(target).write_text(text)
PY

# Stage beside the package, and do not overwrite concurrent edits.
staged="$(mktemp "${pkg_file}.XXXXXX")"
cp -p "$tmp/original" "$staged"
cat "$tmp/default.nix" >"$staged"
cmp -s "$pkg_file" "$tmp/original" || {
    echo "Package changed during update; refusing to overwrite it" >&2
    exit 1
}
mv -f "$staged" "$pkg_file"
staged=''
printf 'twg updated to %s\n' "$version"
