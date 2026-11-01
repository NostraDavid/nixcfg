#!/usr/bin/env bash
set -euo pipefail

root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
file="$root/pkgs/databricks-cli/default.nix"
tmp="$(mktemp -d)"
staged=''
trap 'rm -rf "$tmp"; if [[ -n "$staged" ]]; then rm -f "$staged"; fi' EXIT
cp -p "$file" "$tmp/original"

release="$(curl -fsSL https://api.github.com/repos/databricks/cli/releases/latest)"
version="$(jq -er 'select(.draft == false and .prerelease == false) | .tag_name | select(type == "string" and test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | ltrimstr("v")' <<<"$release")"
targets=(linux_amd64 linux_arm64 darwin_amd64 darwin_arm64)
hashes=()
for target in "${targets[@]}"; do
    name="databricks_cli_${version}_${target}.tar.gz"
    url="https://github.com/databricks/cli/releases/download/v${version}/${name}"
    digest="$(jq -er --arg name "$name" --arg url "$url" '[.assets[] | select(.name == $name and .browser_download_url == $url and .state == "uploaded") | .digest | select(type == "string" and test("^sha256:[0-9a-f]{64}$"))] | select(length == 1) | .[0] | ltrimstr("sha256:")' <<<"$release")"
    curl -fsSL "$url" >"$tmp/$name"
    actual="$(sha256sum "$tmp/$name" | cut -d ' ' -f1)"
    [[ "$actual" == "$digest" ]] || {
        echo "Checksum mismatch: $name" >&2
        exit 1
    }
    hashes+=("$(nix hash file --type sha256 --sri "$tmp/$name")")
done

python3 - "$tmp/original" "$tmp/result" "$version" "${hashes[@]}" <<'PY'
import re
import sys
from pathlib import Path

source, target, version, *hashes = sys.argv[1:]
text = Path(source).read_text()
text, count = re.subn(r'(?m)^(  version = ")[^"]+(";)$', rf'\g<1>{version}\2', text)
if count != 1:
    raise SystemExit('Expected exactly one package version')
for system, digest in zip(('x86_64-linux', 'aarch64-linux', 'x86_64-darwin', 'aarch64-darwin'), hashes, strict=True):
    pattern = rf'(?ms)(^    "{system}" = \{{\n(?:(?!^    \}};).)*?^      hash = ")[^"]+(";\n    \}};)'
    text, count = re.subn(pattern, rf'\g<1>{digest}\2', text)
    if count != 1:
        raise SystemExit(f'Expected exactly one hash for {system}')
Path(target).write_text(text)
PY

staged="$(mktemp "${file}.XXXXXX")"
cp -p "$tmp/original" "$staged"
cat "$tmp/result" >"$staged"
cmp -s "$file" "$tmp/original" || {
    echo 'Package changed during update; refusing to overwrite it' >&2
    exit 1
}
mv -f "$staged" "$file"
staged=''
printf 'databricks-cli updated to %s\n' "$version"
