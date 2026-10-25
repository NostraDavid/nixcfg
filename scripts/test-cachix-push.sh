#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo"
export TEST_ROOT="$tmp"
cat >"$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
    'eval --impure --raw --expr builtins.currentSystem') echo x86_64-linux ;;
    'eval --json .#packages.x86_64-linux --apply pkgs: builtins.attrNames pkgs') echo '["first","second"]' ;;
    'build --no-link --print-out-paths .#first .#second')
        [[ "${TEST_BUILD_FAILURE:-0}" == 0 ]] || exit 17
        printf '/nix/store/first\n/nix/store/second\n'
        ;;
    *) exit 99 ;;
esac
EOF
cat >"$tmp/bin/cachix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'push thaumatorium' ]]
cat >"$TEST_ROOT/pushed"
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
just --justfile "$repo_root/Justfile" --working-directory "$tmp/repo" cachix-push-all
[[ "$(cat "$tmp/pushed")" == $'/nix/store/first\n/nix/store/second' ]]
rm "$tmp/pushed"
if TEST_BUILD_FAILURE=1 just --justfile "$repo_root/Justfile" --working-directory "$tmp/repo" cachix-push-all >"$tmp/output" 2>&1; then
    echo 'Expected failed build to stop the upload' >&2
    exit 1
fi
[[ ! -e "$tmp/pushed" ]]
echo 'Cachix uploads build outputs only after successful builds.'
