#!/usr/bin/env bash
set -euo pipefail
root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repo/scripts" "$tmp/repo/pkgs/databricks-cli" "$tmp/bin"
cp "$root/scripts/update-databricks-cli.sh" "$tmp/repo/scripts/"
cp "$root/pkgs/databricks-cli/default.nix" "$tmp/repo/pkgs/databricks-cli/"
git -C "$tmp/repo" init -q
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
url="${*: -1}"
if [[ "$url" == */releases/latest ]]; then
    python3 - <<'PY'
import hashlib, json
assets = []
for target in ('linux_amd64', 'linux_arm64', 'darwin_amd64', 'darwin_arm64'):
    name = f'databricks_cli_2.0.0_{target}.tar.gz'
    assets.append(dict(name=name, browser_download_url=f'https://github.com/databricks/cli/releases/download/v2.0.0/{name}', state='uploaded', digest='sha256:' + hashlib.sha256(target.encode()).hexdigest()))
print(json.dumps(dict(tag_name='v2.0.0', draft=False, prerelease=False, assets=assets)))
PY
else
    target="${url##*_2.0.0_}"
    target="${target%.tar.gz}"
    [[ "$target" != "${FAIL_TARGET:-}" ]] || exit 22
    if [[ "$target" == "${CORRUPT_TARGET:-}" ]]; then printf corrupt; else printf %s "$target"; fi
fi
EOF
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH"
file="$tmp/repo/pkgs/databricks-cli/default.nix"
printf '\n# dirty user edit\n' >>"$file"
cp "$file" "$tmp/original"
for target in linux_amd64 linux_arm64 darwin_amd64 darwin_arm64; do
    if FAIL_TARGET="$target" bash "$tmp/repo/scripts/update-databricks-cli.sh"; then exit 1; fi
    cmp "$file" "$tmp/original"
    if CORRUPT_TARGET="$target" bash "$tmp/repo/scripts/update-databricks-cli.sh"; then exit 1; fi
    cmp "$file" "$tmp/original"
done
bash "$tmp/repo/scripts/update-databricks-cli.sh"
grep -F 'version = "2.0.0";' "$file"
grep -F '# dirty user edit' "$file"
for target in linux_amd64 linux_arm64 darwin_amd64 darwin_arm64; do
    grep -F "$(printf %s "$target" | nix hash file --type sha256 --sri /dev/stdin)" "$file"
done
