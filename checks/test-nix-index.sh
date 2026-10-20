#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/nix-index" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == --nixpkgs && "$2" == /fixture/nixpkgs ]]
[[ "$3" == --system && "$4" == fixture-system && "$5" == --db ]]
printf 'index\n' >"$6/files"
printf 'called\n' >>"$CALLS"
exit "${FAIL_INDEX:-0}"
SH
chmod +x "$tmp/bin/nix-index"

MODULE="$root/features/nix-index/_home.nix" INDEXER="$tmp" nix eval --impure --raw --expr '
  let module = import (builtins.toPath (builtins.getEnv "MODULE")) {
    inputs.nixpkgs-unstable = "/fixture/nixpkgs";
    lib.hm.dag.entryAfter = _: data: data;
    unstable = {
      nix-index = builtins.getEnv "INDEXER";
      stdenv.hostPlatform.system = "fixture-system";
    };
  }; in module.home.activation.nixIndex
' >"$tmp/activate.sh"

export CALLS="$tmp/calls" HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache with spaces"
unset NIX_INDEX_DATABASE DRY_RUN_CMD
bash -e "$tmp/activate.sh"
test -s "$XDG_CACHE_HOME/nix-index/files"
printf 'existing index\n' >"$XDG_CACHE_HOME/nix-index/files"
bash -e "$tmp/activate.sh"
test "$(wc -l <"$CALLS")" -eq 1
test "$(cat "$XDG_CACHE_HOME/nix-index/files")" = 'existing index'

export NIX_INDEX_DATABASE="$tmp/custom database"
if FAIL_INDEX=1 bash -e "$tmp/activate.sh"; then
    echo "Failed index generation unexpectedly succeeded" >&2
    exit 1
fi
test ! -e "$NIX_INDEX_DATABASE/files"
bash -e "$tmp/activate.sh"
test -s "$NIX_INDEX_DATABASE/files"
test "$(wc -l <"$CALLS")" -eq 3

NIX_INDEX_DATABASE="$tmp/dry-run" DRY_RUN_CMD=echo bash -e "$tmp/activate.sh"
test ! -e "$tmp/dry-run"
test "$(wc -l <"$CALLS")" -eq 3

mkdir -p "$HOME/.cache/nix-index"
touch "$HOME/.cache/nix-index/files"
NIX_INDEX_DATABASE="" XDG_CACHE_HOME="" bash -e "$tmp/activate.sh"
test -s "$HOME/.cache/nix-index/files"
test "$(wc -l <"$CALLS")" -eq 4
echo "PASS: missing, existing and empty index, failed build, retry, cache paths and dry run"
