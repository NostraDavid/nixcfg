#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export MIGRATION_TEST_STATE="$tmp"
cat >"$tmp/bin/mock" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state=$MIGRATION_TEST_STATE
tool=${0##*/}
if [[ $tool == sudo ]]; then
    [[ $1 == -H && $2 == -u && $3 == work ]]
    shift 3
    exec "$@"
fi
printf '%s %s\n' "$tool" "$*" >> "$state/log"
case "$tool $1" in
"pkgutil --check-signature")
    [[ ${FAIL_SIGNATURE:-0} == 0 ]]
    ;;
"pkgutil --pkg-info")
    [[ -f $state/version ]]
    printf 'version: %s\n' "$(cat "$state/version")"
    ;;
"brew list")
    [[ ${FAIL_LIST:-0} == 0 ]]
    cat "$state/casks"
    ;;
"brew uninstall")
    [[ ${FAIL_UNINSTALL:-0} == 0 ]]
    grep -Fxv "$3" "$state/casks" > "$state/remaining" || true
    mv "$state/remaining" "$state/casks"
    if [[ $3 == karabiner-elements ]]; then
        rm -f "$state/version"
    fi
    ;;
"installer -pkg")
    [[ ${FAIL_INSTALL:-0} == 0 ]]
    printf '16.3.0\n' > "$state/version"
    ;;
*) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/mock"
for tool in sudo brew pkgutil installer; do
    ln -s mock "$tmp/bin/$tool"
done
export PATH="$tmp/bin:$PATH"
printf 'karabiner-elements\nalt-tab\nunrelated-app\n' >"$tmp/casks"
printf '16.3.0\n' >"$tmp/version"

bash "$root/scripts/migrate-darwin-apps.sh" work 16.3.0 'signed installer.pkg'
[[ $(cat "$tmp/casks") == unrelated-app ]]
[[ $(cat "$tmp/version") == 16.3.0 ]]
grep -Fxq 'installer -pkg signed installer.pkg -target /' "$tmp/log"
bash "$root/scripts/migrate-darwin-apps.sh" work 16.3.0 'signed installer.pkg'
[[ $(grep -c '^installer ' "$tmp/log") == 1 ]]
[[ $(grep -c '^brew uninstall ' "$tmp/log") == 2 ]]

for failure in FAIL_SIGNATURE FAIL_LIST FAIL_UNINSTALL; do
    printf 'alt-tab\nunrelated-app\n' >"$tmp/casks"
    if env "$failure=1" bash "$root/scripts/migrate-darwin-apps.sh" work 16.3.0 'signed installer.pkg'; then
        echo "Expected $failure to stop migration" >&2
        exit 1
    fi
    [[ $(cat "$tmp/casks") == $'alt-tab\nunrelated-app' ]]
done

# A failed installer leaves the old version, so the next activation retries.
printf '15.7.0\n' >"$tmp/version"
if FAIL_INSTALL=1 bash "$root/scripts/migrate-darwin-apps.sh" work 16.3.0 'signed installer.pkg'; then
    echo 'Expected installer failure to stop activation' >&2
    exit 1
fi
[[ $(cat "$tmp/version") == 15.7.0 ]]
bash "$root/scripts/migrate-darwin-apps.sh" work 16.3.0 'signed installer.pkg'
[[ $(cat "$tmp/version") == 16.3.0 ]]
mv "$tmp/bin/brew" "$tmp/bin/brew-disabled"
bash "$root/scripts/migrate-darwin-apps.sh" work 16.3.0 'signed installer.pkg'
printf 'Darwin application migration: OK\n'
