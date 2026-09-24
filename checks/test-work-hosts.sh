#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nix eval --raw "path:$root#homeConfigurations.\"david@mimir2\".activationPackage.drvPath" >/dev/null
nix eval --raw "path:$root#darwinConfigurations.loki.config.system.build.toplevel.drvPath" >/dev/null
nix eval --raw "path:$root#nixosConfigurations.wodan.config.system.build.toplevel.drvPath" >/dev/null

cat >"$tmp/flake.nix" <<EOF
{
  inputs.nixcfg.url = "path:$root";

  outputs = {nixcfg, ...}: {
    homeConfigurations."david@mimir2" = nixcfg.lib.mkMimir2 {
      extraHomeModules = [{home.sessionVariables.NIXCFG_EXTENSION_PROBE = "yes";}];
    };
    darwinConfigurations.loki = nixcfg.lib.mkLoki {
      extraHomeModules = [{home.sessionVariables.NIXCFG_EXTENSION_PROBE = "yes";}];
      extraDarwinModules = [{environment.variables.NIXCFG_EXTENSION_PROBE = "yes";}];
    };
  };
}
EOF

if ! nix flake lock "path:$tmp" >"$tmp/lock.log" 2>&1; then
    cat "$tmp/lock.log" >&2
    exit 1
fi

test "$(nix eval --raw "path:$tmp#homeConfigurations.\"david@mimir2\".config.home.sessionVariables.NIXCFG_EXTENSION_PROBE")" = yes
test "$(nix eval --raw "path:$tmp#darwinConfigurations.loki.config.home-manager.users.david.home.sessionVariables.NIXCFG_EXTENSION_PROBE")" = yes
test "$(nix eval --raw "path:$tmp#darwinConfigurations.loki.config.environment.variables.NIXCFG_EXTENSION_PROBE")" = yes
