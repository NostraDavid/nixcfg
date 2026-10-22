#!/usr/bin/env bash
set -euo pipefail

profile_bin="${1:?Missing profile directory}/bin"
local_bin="${2:?Missing destination directory}"
if [[ ! -d "$profile_bin" ]]; then
    printf 'Package command directory does not exist: %s\n' "$profile_bin" >&2
    exit 1
fi

mkdir -p "$local_bin"
for executable in "$profile_bin"/*; do
    [[ -f "$executable" && -x "$executable" ]] || continue
    target="$local_bin/${executable##*/}"
    [[ -e "$target" || -L "$target" ]] && continue
    ln -s "$executable" "$target"
done
