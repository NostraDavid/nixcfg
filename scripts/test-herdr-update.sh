#!/usr/bin/env bash
set -euo pipefail

root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repo/scripts" "$tmp/repo/pkgs" "$tmp/bin"
cp -a "$root/pkgs/herdr-app" "$root/pkgs/herdr-core" "$tmp/repo/pkgs/"
cp -a "$root/scripts/update-herdr"*.sh "$tmp/repo/scripts/"
git init -q "$tmp/repo"
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -fsSL && "$2" == "https://releases.herdr.dev/${HERDR_KIND}/latest.json" ]]
cat "$MANIFEST"
EOF
cat >"$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == build ]]; then
    if [[ "${CONCURRENT_EDIT:-0}" == 1 ]]; then
        printf '\n# concurrent edit\n' >>"$EDIT_FILE"
    fi
    [[ "${FAIL_BUILD:-0}" == 0 ]]
else
    "$REAL_NIX" "$@"
fi
EOF
chmod +x "$tmp/bin/"*
REAL_NIX="$(command -v nix)"
export REAL_NIX MANIFEST="$tmp/manifest.json" PATH="$tmp/bin:$PATH"
for kind in app core; do
    export HERDR_KIND="$kind"
    file="$tmp/repo/pkgs/herdr-$kind/default.nix"
    jq -n --arg kind "$kind" '{version:"9.8.7", targets: (reduce ["linux-x86_64", "linux-aarch64", "macos-aarch64"][] as $target ({}; .[$target] = {url:("https://releases.herdr.dev/"+$kind+"/9.8.7/herdr-"+$kind+"-"+$target+".tar.gz"), sha256:("ab" * 32)}))}' >"$MANIFEST"
    bash "$tmp/repo/scripts/update-herdr-$kind.sh"
    grep -q 'version = "9.8.7";' "$file"
    [[ "$(grep -c 'sha256-q6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq6s=' "$file")" == 3 ]]
    printf '\n# pre-existing dirty edit\n' >>"$file"
    cp "$file" "$tmp/before"
    jq '.version = "9.8.6" | .targets |= with_entries(.value.url |= sub("/9.8.7/"; "/9.8.6/"))' "$MANIFEST" >"$tmp/next"
    mv "$tmp/next" "$MANIFEST"
    if FAIL_BUILD=1 bash "$tmp/repo/scripts/update-herdr-$kind.sh"; then exit 1; fi
    cmp "$tmp/before" "$file"
    if EDIT_FILE="$file" CONCURRENT_EDIT=1 FAIL_BUILD=1 bash "$tmp/repo/scripts/update-herdr-$kind.sh" 2>"$tmp/error"; then exit 1; fi
    grep -q 'Not rolling back' "$tmp/error"
    grep -q '^# pre-existing dirty edit$' "$file"
    grep -q '^# concurrent edit$' "$file"
    grep -q 'version = "9.8.6";' "$file"
    cp "$file" "$tmp/before"
    jq '.targets["linux-x86_64"].url = "https://example.com/wrong"' "$MANIFEST" >"$tmp/bad"
    cp "$MANIFEST" "$tmp/good"
    mv "$tmp/bad" "$MANIFEST"
    if bash "$tmp/repo/scripts/update-herdr-$kind.sh"; then exit 1; fi
    cmp "$tmp/before" "$file"
    cp "$tmp/good" "$MANIFEST"
    jq 'del(.targets["linux-aarch64"])' "$MANIFEST" >"$tmp/bad"
    mv "$tmp/bad" "$MANIFEST"
    if bash "$tmp/repo/scripts/update-herdr-$kind.sh"; then exit 1; fi
    cmp "$tmp/before" "$file"
done
printf 'Herdr updater regression checks passed.\n'
