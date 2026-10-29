#!/usr/bin/env bash
set -euo pipefail

root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repo/scripts" "$tmp/repo/pkgs/synology-drive-client-pinned" "$tmp/bin"
cp "$root/scripts/update-synology-drive-client-pinned.sh" "$tmp/repo/scripts/"
cat >"$tmp/repo/pkgs/synology-drive-client-pinned/default.nix" <<'NIX'
version = "4.2.1-20062";
linuxSrc = fetchurl {
  hash = "old-linux";
};
darwinSrc = fetchurl {
  hash = "old-darwin";
};
NIX
export TEST_REPO="$tmp/repo"
cat >"$tmp/bin/git" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$TEST_REPO"
MOCK
cat >"$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' '{"info":{"versions":{"all":{"all_versions":[{"version":"4.0.4-17894"},{"version":"4.2.1-20062"},{"version":"4.2.0-20058"}]}}}}'
MOCK
cat >"$tmp/bin/nix" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == store ]]; then printf '{"hash":"test-hash"}\n'; fi
MOCK
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
bash "$tmp/repo/scripts/update-synology-drive-client-pinned.sh"
rg -q 'version = "4.2.1-20062";' "$tmp/repo/pkgs/synology-drive-client-pinned/default.nix"
if bash "$tmp/repo/scripts/update-synology-drive-client-pinned.sh" 4.0.4-17894; then
    echo 'Downgrade was not rejected' >&2
    exit 1
fi
rg -q 'version = "4.2.1-20062";' "$tmp/repo/pkgs/synology-drive-client-pinned/default.nix"
echo 'Synology version selection and downgrade protection passed.'
