#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
nix_command=$(command -v nix)
mkdir -p "$tmp/repo/scripts" "$tmp/repo/hosts" "$tmp/bin"
cp "$root/scripts/bootstrap-host.sh" "$tmp/repo/scripts/"
printf '{}\n' >"$tmp/repo/flake.nix"
cat >"$tmp/repo/hosts/default.nix" <<'NIX'
{
  imports = [
  ];
}
NIX
cat >"$tmp/bin/nixos-generate-config" <<'SH'
#!/usr/bin/env bash
printf '{...}: {}\n'
exit "${FAIL_HARDWARE:-0}"
SH
cat >"$tmp/bin/nix" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BOOTSTRAP_NIX_CALLS"
SH
chmod +x "$tmp/bin/nixos-generate-config" "$tmp/bin/nix"
export BOOTSTRAP_NIX_CALLS="$tmp/nix-calls"

for mode in laptop workstation; do
    PATH="$tmp/bin:$PATH" bash "$tmp/repo/scripts/bootstrap-host.sh" "fixture-$mode" "$mode" >"$tmp/$mode.log"
    # shellcheck disable=SC2016
    HOST_MODULE="$tmp/repo/hosts/physical/fixture-$mode/default.nix" HOST_NAME="fixture-$mode" "$nix_command" eval --impure --json --expr '
      let
        name = builtins.getEnv "HOST_NAME";
        result = import (builtins.toPath (builtins.getEnv "HOST_MODULE")) {
          den = {
            aspects = result.den.aspects // {
              kde-workstation.name = "kde-workstation";
              laptop.name = "laptop";
            };
            batteries.host-aspects.name = "host-aspects";
          };
          constructors.nixos = args: args;
          inputs = {
            plasma-manager.homeModules.plasma-manager = {};
            codex-desktop-linux.homeManagerModules.default = {};
          };
        };
        host = result.den.hosts.x86_64-linux.${name};
        aspect = result.den.aspects.${"host-" + name};
        system = aspect.nixos {pkgs.linuxPackages_latest = "kernel";};
      in {
        inherit (host.instantiate) hostname homeManager;
        classes = host.users.david.classes;
        projection = map (a: a.name) host.users.david.aspect.includes;
        includes = map (a: a.name) aspect.includes;
        system = {inherit (system.networking) hostName;inherit (system.system) stateVersion;};
        home = aspect.homeManager.home;
      }
    ' >"$tmp/$mode.json"
done

python3 - "$tmp" <<'PY'
import json
import sys
from pathlib import Path

tmp = Path(sys.argv[1])
for mode in ("laptop", "workstation"):
    result = json.loads((tmp / f"{mode}.json").read_text())
    assert result["hostname"] == result["system"]["hostName"] == f"fixture-{mode}"
    assert result["homeManager"] is True
    assert result["classes"] == ["homeManager"]
    assert result["projection"] == ["host-aspects"]
    assert result["includes"] == ["kde-workstation"] + (["laptop"] if mode == "laptop" else [])
    assert result["home"] == {"username": "david", "homeDirectory": "/home/david", "stateVersion": "25.05"}
    assert f"./physical/fixture-{mode}" in (tmp / "repo/hosts/default.nix").read_text()
    assert (tmp / f"repo/hosts/physical/fixture-{mode}/hardware-configuration.nix").exists()
index = (tmp / "repo/hosts/default.nix").read_text().splitlines()
imports = [line.strip() for line in index if line.strip().startswith("./")]
assert imports == sorted(imports)
assert len((tmp / "nix-calls").read_text().splitlines()) == 2
PY

cp "$tmp/repo/hosts/physical/fixture-laptop/default.nix" "$tmp/before.nix"
if PATH="$tmp/bin:$PATH" bash "$tmp/repo/scripts/bootstrap-host.sh" fixture-laptop laptop >"$tmp/repeated.log" 2>&1; then
    echo 'Bootstrap unexpectedly overwrote an existing host' >&2
    exit 1
fi
cmp "$tmp/before.nix" "$tmp/repo/hosts/physical/fixture-laptop/default.nix"
cp "$tmp/repo/hosts/default.nix" "$tmp/index-before.nix"
if FAIL_HARDWARE=1 PATH="$tmp/bin:$PATH" bash "$tmp/repo/scripts/bootstrap-host.sh" fixture-failure laptop >"$tmp/failure.log" 2>&1; then
    echo 'Bootstrap unexpectedly accepted failed hardware generation' >&2
    exit 1
fi
test ! -e "$tmp/repo/hosts/physical/fixture-failure"
test ! -e "$tmp/repo/hosts/physical/fixture-failure/default.nix"
cmp "$tmp/index-before.nix" "$tmp/repo/hosts/default.nix"
mkdir -p "$tmp/repo/hosts/virtual/fixture-virtual"
if PATH="$tmp/bin:$PATH" bash "$tmp/repo/scripts/bootstrap-host.sh" fixture-virtual laptop >"$tmp/virtual.log" 2>&1; then
    echo 'Bootstrap unexpectedly reused an existing virtual host name' >&2
    exit 1
fi
test ! -e "$tmp/repo/hosts/physical/fixture-virtual"
cmp "$tmp/index-before.nix" "$tmp/repo/hosts/default.nix"
echo 'PASS: native Den laptop/workstation bootstrap, host identity, projection, overwrite rejection and hardware failure cleanup'
