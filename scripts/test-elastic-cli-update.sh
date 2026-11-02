#!/usr/bin/env bash
set -euo pipefail
root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repo/scripts" "$tmp/repo/pkgs/elastic-cli" "$tmp/bin"
cp "$root/scripts/update-elastic-cli.sh" "$tmp/repo/scripts/"
git -C "$tmp/repo" init -q
export TEST_REPO="$tmp/repo"
cat >"$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
file="$TEST_REPO/pkgs/elastic-cli/default.nix"
case "$*" in
    'run nixpkgs#nix-update -- -F elastic-cli')
        sed -i -e 's/version = "old"/version = "new"/' -e 's/hash = "old"/hash = "new"/g' "$file"
        [[ "${FAIL:-}" != update ]] || exit 17
        ;;
    'build path:.#elastic-cli --no-link')
        grep -q 'version = "new"' "$file"
        [[ $(grep -c 'hash = "new"' "$file") == 2 ]]
        case "${FAIL:-}" in
            build) exit 18 ;;
            concurrent) echo '# concurrent edit' >>"$file"; exit 18 ;;
            conflict) sed -i 's/version = "new"/version = "other"/' "$file"; exit 18 ;;
        esac
        ;;
    *) exit 99 ;;
esac
EOF
chmod +x "$tmp/bin/nix"
export PATH="$tmp/bin:$PATH"
file="$TEST_REPO/pkgs/elastic-cli/default.nix"
for failure in none update build concurrent conflict; do
    cat >"$file" <<'EOF'
version = "old";
hash = "old";
npm hash = "old";




# existing edit
EOF
    cp "$file" "$tmp/original"
    status=0
    FAIL="$failure" bash "$tmp/repo/scripts/update-elastic-cli.sh" >"$tmp/output" 2>&1 || status=$?
    case "$failure" in
    none)
        [[ $status == 0 ]]
        grep -q 'version = "new"' "$file"
        ;;
    update)
        [[ $status == 17 ]]
        cmp "$file" "$tmp/original"
        ;;
    build)
        [[ $status == 18 ]]
        cmp "$file" "$tmp/original"
        ;;
    concurrent)
        [[ $status == 18 ]]
        grep -q 'version = "old"' "$file"
        grep -q '^# concurrent edit$' "$file"
        ;;
    conflict)
        [[ $status == 18 ]]
        grep -q 'version = "other"' "$file"
        grep -q 'conflict with rollback' "$tmp/output"
        ;;
    esac
done
echo 'Elastic CLI updater verifies and safely rolls back updates.'
