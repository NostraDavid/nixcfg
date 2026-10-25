#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export TEST_REPO="$tmp/repo" TEST_ROOT="$tmp"
mkdir -p "$TEST_REPO/pkgs/paperclip" "$tmp/bin" "$tmp/node/bin" "$tmp/package"
git init -q "$TEST_REPO"
printf '{"name":"paperclipai","version":"2.0.0"}\n' >"$tmp/package/package.json"
tar -czf "$tmp/source.tgz" -C "$tmp" package/package.json
cat >"$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_ROOT/calls"
case "$*" in
    'run nixpkgs#nix-update -- -F paperclip --src-only')
        echo '# source updated' >>"$TEST_REPO/pkgs/paperclip/default.nix"
        ;;
    'build .#paperclip.src --no-link --print-out-paths')
        [[ "${TEST_FAILURE:-}" != source ]] || exit 17
        echo "$TEST_ROOT/source.tgz"
        ;;
    'build .#paperclip.nodejs --no-link --print-out-paths') echo "$TEST_ROOT/node" ;;
    'eval --json .#paperclip.npmOverrides') echo '{"svix":{"uuid":"11.1.1"}}' ;;
    'run nixpkgs#nix-update -- -F paperclip --version=skip')
        echo '# dependencies updated' >>"$TEST_REPO/pkgs/paperclip/default.nix"
        ;;
    'build .#paperclip --no-link')
        [[ "${TEST_FAILURE:-}" != build ]] || exit 17
        jq -e '.packages["node_modules/uuid"].version == "11.1.1"' "$TEST_REPO/pkgs/paperclip/package-lock.json" >/dev/null
        ;;
    *) exit 99 ;;
esac
EOF
cat >"$tmp/node/bin/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'install --package-lock-only --ignore-scripts --no-audit --no-fund --prefix '* ]]
while [[ "$1" != --prefix ]]; do shift; done
source="$2"
jq -e '.overrides.svix.uuid == "11.1.1"' "$source/package.json" >/dev/null
jq -e '.existingUserChange' "$source/package-lock.json" >/dev/null
[[ "${TEST_FAILURE:-}" != npm ]] || exit 17
jq '.packages["node_modules/uuid"].version = "11.1.1"' "$source/package-lock.json" >"$source/updated.json"
mv "$source/updated.json" "$source/package-lock.json"
EOF
chmod +x "$tmp/bin/nix" "$tmp/node/bin/npm"
export PATH="$tmp/bin:$PATH"
cd "$TEST_REPO"
for failure in none source npm build; do
    printf '# existing user changes\n' >pkgs/paperclip/default.nix
    printf '{"existingUserChange":true,"packages":{"node_modules/uuid":{"version":"10.0.0"}}}\n' >pkgs/paperclip/package-lock.json
    cp pkgs/paperclip/default.nix "$tmp/before.nix"
    cp pkgs/paperclip/package-lock.json "$tmp/before.json"
    status=0
    TEST_FAILURE="$failure" bash "$repo_root/scripts/update-paperclip.sh" >"$tmp/output" 2>&1 || status=$?
    if [[ "$failure" == none ]]; then
        [[ "$status" == 0 ]]
        jq -e '.packages["node_modules/uuid"].version == "11.1.1"' pkgs/paperclip/package-lock.json >/dev/null
        rg -q '^# dependencies updated$' pkgs/paperclip/default.nix
    else
        [[ "$status" == 17 ]]
        cmp "$tmp/before.nix" pkgs/paperclip/default.nix
        cmp "$tmp/before.json" pkgs/paperclip/package-lock.json
    fi
done
echo 'Paperclip updater preserves overrides, verifies builds, and rolls back failures.'
