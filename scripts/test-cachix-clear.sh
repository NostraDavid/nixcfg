#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "$repo_root"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/runtime"
export MOCK_ROOT="$test_root" CACHIX_AUTH_TOKEN=test-token XDG_RUNTIME_DIR="$test_root/runtime"
export PATH="$test_root/bin:$PATH"

cat >"$test_root/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$(cat)" == 'header = "Authorization: Bearer test-token"' ]] || exit 2
method=GET
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ "${args[i]}" == -X ]]; then method="${args[i + 1]}"; fi
done
url="${args[-1]}"
base='https://app.cachix.org/api/v1/cache/thaumatorium'
[[ "$url" == "$base/"* ]] || exit 2
path="${url#"$base"}"
printf '%s %s\n' "$method" "$path" >> "$MOCK_ROOT/calls"
case "$method $path" in
    'GET /details')
        if [[ -f "$MOCK_ROOT/key-changed" ]]; then key=other; else key=key; fi
        printf '{"name":"thaumatorium","publicSigningKeys":["%s"]}\n' "$key" ;;
    'GET /contents')
        if [[ "$(cat "$MOCK_ROOT/paths")" == 0 ]]; then echo '[]'; else echo '["one","two"]'; fi ;;
    'GET /pin')
        if [[ "$(cat "$MOCK_ROOT/pins")" == 0 ]]; then echo '[]'; else echo '[{"name":"codex"}]'; fi ;;
    'POST /clear')
        if [[ -f "$MOCK_ROOT/fail-clear" ]]; then echo 'mock clear failure' >&2; exit 22; fi
        echo 0 > "$MOCK_ROOT/paths"
        if [[ -f "$MOCK_ROOT/change-key-on-clear" ]]; then touch "$MOCK_ROOT/key-changed"; fi ;;
    'POST /pin/clear') echo 0 > "$MOCK_ROOT/pins" ;;
    *) exit 2 ;;
esac
MOCK
chmod +x "$test_root/bin/curl"

reset_mock() {
    echo 2 >"$test_root/paths"
    echo 1 >"$test_root/pins"
    : >"$test_root/calls"
    rm -f "$test_root/fail-clear" "$test_root/change-key-on-clear" "$test_root/key-changed"
}
run_tty() {
    printf '%s\n' "$1" | script -q -e -c 'just cachix-clear' /dev/null
}
no_post() {
    if rg -q '^POST ' "$test_root/calls"; then
        echo 'Unexpected Cachix POST' >&2
        exit 1
    fi
}

reset_mock
if just cachix-clear </dev/null >"$test_root/output" 2>&1; then
    echo 'Expected TTY guard' >&2
    exit 1
fi
no_post

reset_mock
if CACHIX_AUTH_TOKEN='bad"token' just cachix-clear </dev/null >"$test_root/output" 2>&1; then
    echo 'Expected token validation' >&2
    exit 1
fi
[[ ! -s "$test_root/calls" ]]

reset_mock
if run_tty wrong >"$test_root/output" 2>&1; then
    echo 'Expected confirmation guard' >&2
    exit 1
fi
no_post

reset_mock
run_tty thaumatorium >"$test_root/output" 2>&1
mapfile -t posts < <(rg '^POST ' "$test_root/calls")
[[ "${posts[*]}" == 'POST /clear POST /pin/clear' ]]
[[ "$(cat "$test_root/paths")" == 0 && "$(cat "$test_root/pins")" == 0 ]]
rg -q 'configuratie en signing key zijn behouden' "$test_root/output"

reset_mock
touch "$test_root/fail-clear"
if run_tty thaumatorium >"$test_root/output" 2>&1; then
    echo 'Expected API failure' >&2
    exit 1
fi
mapfile -t posts < <(rg '^POST ' "$test_root/calls")
[[ "${posts[*]}" == 'POST /clear' ]]
rg -q 'mock clear failure' "$test_root/output"

reset_mock
touch "$test_root/change-key-on-clear"
if run_tty thaumatorium >"$test_root/output" 2>&1; then
    echo 'Expected signing key check' >&2
    exit 1
fi
rg -q 'signing key is veranderd' "$test_root/output"

reset_mock
echo 0 >"$test_root/paths"
echo 0 >"$test_root/pins"
: >"$test_root/calls"
mkdir -p "$test_root/config/cachix"
printf '"test-token"\n' >"$test_root/config/cachix/cachix.dhall"
export XDG_CONFIG_HOME="$test_root/config"
unset CACHIX_AUTH_TOKEN
just cachix-clear </dev/null >"$test_root/output" 2>&1
no_post

echo 'Cachix clear mock checks passed.'
