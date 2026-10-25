#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/first/bin" "$tmp/second/bin"
for generation in first second; do
    cat >"$tmp/$generation/bin/git" <<EOF
#!/bin/sh
printf '%s\n' '$generation'
EOF
    chmod +x "$tmp/$generation/bin/git"
done
cp "$tmp/first/bin/git" "$tmp/first/bin/tool with spaces"
for name in code custom manual; do
    cp "$tmp/first/bin/git" "$tmp/first/bin/$name"
done
printf 'not executable\n' >"$tmp/first/bin/data"
mkdir "$tmp/first/bin/directory"

for layout in etc/profiles/per-user/test home/test/.nix-profile home/test/.local/state/nix/profile; do
    profile="$tmp/$layout"
    local_bin="$tmp/$layout-local bin"
    mkdir -p "$(dirname "$profile")" "$local_bin"
    ln -s "$tmp/first" "$profile"
    printf 'personal script\n' >"$local_bin/code"
    ln -s "$tmp/missing-user-command" "$local_bin/custom"
    ln -s "$tmp/first/bin/git" "$local_bin/manual"
    for _ in first second; do
        bash "$root/features/common-tooling/link-package-commands.sh" "$profile" "$local_bin"
        [[ $(readlink "$local_bin/git") == "$profile/bin/git" ]]
        [[ $("$local_bin/git") == first ]]
        [[ $("$local_bin/tool with spaces") == first ]]
        [[ ! -e "$local_bin/data" && ! -e "$local_bin/directory" ]]
        [[ $(cat "$local_bin/code") == 'personal script' ]]
        [[ $(readlink "$local_bin/custom") == "$tmp/missing-user-command" ]]
        [[ $(readlink "$local_bin/manual") == "$tmp/first/bin/git" ]]
    done
    rm "$profile"
    ln -s "$tmp/second" "$profile"
    [[ $("$local_bin/git") == second ]]
    bash "$root/features/common-tooling/link-package-commands.sh" "$profile" "$local_bin"
    [[ $("$local_bin/git") == second ]]
done

if bash "$root/features/common-tooling/link-package-commands.sh" "$tmp/missing" "$tmp/unused" 2>"$tmp/error"; then
    echo 'Expected a missing-profile failure' >&2
    exit 1
fi
[[ ! -e "$tmp/unused" ]]
nix eval --impure --file "$root/checks/tooling.nix" commandPaths >/dev/null
links=$(FIXTURE_DOTFILES_ROOT="$tmp/live checkout" nix build --impure --file "$root/checks/live-dotfiles.nix" --no-link --print-out-paths)
python3 - "$links" "$tmp/live checkout/dotfiles" <<'PY'
import os
from pathlib import Path
import sys

links, dotfiles = map(Path, sys.argv[1:])
count = 0
for directory, _, files in os.walk(links):
    for name in files:
        deployed = Path(directory) / name
        source = Path(os.readlink(deployed))
        assert source.is_symlink(), source
        target = Path(os.readlink(source))
        assert target.is_relative_to(dotfiles), target
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("before\n")
        assert deployed.read_text() == "before\n"
        target.write_text("after\n")
        assert deployed.read_text() == "after\n"
        count += 1
assert count == 6, count
PY
nix eval --impure --raw --file "$root/checks/tooling.nix" desktopIdeLauncher >"$tmp/ide-desktop.sh"
python3 - "$tmp" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys

tmp = Path(sys.argv[1])
home = tmp / "desktop home"
bin_dir = home / ".local/bin"
bin_dir.mkdir(parents=True)
ide = bin_dir / "ide"
ide.write_text(f"#!{sys.executable}\n" + '''
import json, os, pathlib, sys
pathlib.Path(os.environ["IDE_CAPTURE"]).write_text(json.dumps({
    "args": sys.argv[1:], "path": os.environ["PATH"],
}))
''')
ide.chmod(0o755)
capture = tmp / "ide-capture.json"
env = dict(os.environ, HOME=str(home), IDE_CAPTURE=str(capture))
subprocess.run(["bash", str(tmp / "ide-desktop.sh"), "--new-window", "project with spaces"], env=env, check=True)
result = json.loads(capture.read_text())
assert result["args"] == ["--no-picker", "--", "--new-window", "project with spaces"]
assert result["path"].split(os.pathsep)[0] == str(bin_dir)
PY
printf 'Portable command path checks passed.\n'
