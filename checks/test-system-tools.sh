#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
unset DEVENV_DOTFILE
mkdir host project
cd project
export TEST_SOURCE="$root"
nix eval --raw --impure --expr '
  let
    root = builtins.toPath (builtins.getEnv "TEST_SOURCE");
    pkgs = (builtins.getFlake (toString root)).inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
    probe = (pkgs.writeShellScriptBin "nd-version-probe" "echo fallback").overrideAttrs {
      pname = "nd-version-probe";
      version = "4.1.2";
    };
  in import (root + "/nix/system-tools.nix") (pkgs // { inherit probe; }) [{ attr = "probe"; command = "nd-version-probe"; }]
' >hook
export PATH="$tmp/host:$PATH"
for version in 4.1.3 4.1.1 5.0.0 missing 4.1.3; do
    if [[ $version == missing ]]; then
        rm "$tmp/host/nd-version-probe"
    else
        printf '#!/bin/sh\necho "host %s"\n' "$version" >"$tmp/host/nd-version-probe"
        chmod +x "$tmp/host/nd-version-probe"
    fi
    result=$(bash -eu -c 'source ./hook; nd-version-probe')
    if [[ $version == 4.1.3 ]]; then
        [[ $result == "host $version" && ! -e .direnv/system-tools/nd-version-probe ]]
    else
        [[ $result == fallback && -L .direnv/system-tools/nd-version-probe ]]
    fi
done
