#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fixture_home="$tmp/home with spaces"
mkdir -p "$fixture_home/.config/plocate" "$tmp/files/skip with spaces"
ln -s "$root/dotfiles/plocate/.config/plocate/updatedb.conf" "$fixture_home/.config/plocate/updatedb.conf"
touch "$tmp/files/user-locate-marker" "$tmp/files/skip with spaces/user-locate-hidden"
commands=$(nix build --impure --file "$root/checks/user-locate.nix" --argstr fixtureHome "$fixture_home" commands --no-link --print-out-paths)
"$commands/bin/updatedb" --help >/dev/null
for _ in first second; do
    "$commands/bin/updatedb" --database-root="$tmp/files" --add-single-prunepath="$tmp/files/skip with spaces"
    for query in locate plocate; do
        [[ $("$commands/bin/$query" user-locate-marker) == "$tmp/files/user-locate-marker" ]]
        if "$commands/bin/$query" user-locate-hidden; then
            echo 'Pruned files must not be indexed' >&2
            exit 1
        fi
    done
done
python3 - "$fixture_home/cache with spaces/plocate" <<'PY'
from pathlib import Path
import os
import sys

directory = Path(sys.argv[1])
database = directory / "plocate.db"
assert directory.stat().st_mode & 0o777 == 0o700
assert database.stat().st_mode & 0o007 == 0
assert database.stat().st_uid == os.getuid()
PY
printf 'User plocate database checks passed.\n'
