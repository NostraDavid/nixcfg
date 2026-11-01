#!/usr/bin/env bash
set -euo pipefail
root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repo/scripts" "$tmp/repo/pkgs/twg" "$tmp/bin"
cp "$root/scripts/update-twg.sh" "$tmp/repo/scripts/"
cp "$root/pkgs/twg/default.nix" "$tmp/repo/pkgs/twg/"
git -C "$tmp/repo" init -q
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
case "${*: -1}" in
*/manifest.json) printf '{"channel":"%s","version":"%s"}' "${TEST_CHANNEL:-stable}" "${TEST_VERSION:-2.0.0}" ;;
*/twg-linux-x64-v2.0.0) printf linux ;;
*/twg-darwin-arm64-v2.0.0) [[ "${FAIL_DARWIN:-0}" != 1 ]] || exit 22; printf darwin ;;
*) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH"
file="$tmp/repo/pkgs/twg/default.nix"
cp "$file" "$tmp/original"
if TEST_VERSION='2.0.0/invalid' bash "$tmp/repo/scripts/update-twg.sh"; then exit 1; fi
cmp "$file" "$tmp/original"
if TEST_CHANNEL=beta bash "$tmp/repo/scripts/update-twg.sh"; then exit 1; fi
cmp "$file" "$tmp/original"
if FAIL_DARWIN=1 bash "$tmp/repo/scripts/update-twg.sh"; then exit 1; fi
cmp "$file" "$tmp/original"
bash "$tmp/repo/scripts/update-twg.sh"
grep -F 'version = "2.0.0";' "$file"
grep -F "$(printf linux | nix hash file --type sha256 --sri /dev/stdin)" "$file"
grep -F "$(printf darwin | nix hash file --type sha256 --sri /dev/stdin)" "$file"
