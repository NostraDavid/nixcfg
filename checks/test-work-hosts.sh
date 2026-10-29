#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nix eval --impure --expr "let f = builtins.getFlake \"path:$root\"; p = f.darwinConfigurations.loki.pkgs; m = f.lib.den.aspects.host-loki.homeManager { local = {}; unstable = {}; }; jdk = (builtins.head m.imports) { pkgs = p; }; in assert builtins.elem p.jdk17 jdk.home.packages; true" | grep -qx true

nix eval --raw "path:$root#homeConfigurations.\"mimir2\".activationPackage.drvPath" >/dev/null
nix eval --raw "path:$root#darwinConfigurations.loki.config.system.build.toplevel.drvPath" >/dev/null
nix eval --raw "path:$root#nixosConfigurations.wodan.config.system.build.toplevel.drvPath" >/dev/null

nix eval --json "path:$root#darwinConfigurations.loki.config.homebrew.casks" \
    --apply 'map (cask: cask.name)' |
    jq -e 'index("chatgpt") != null and index("ksnip") != null and index("rectangle") == null and index("alfred") != null' >/dev/null
nix eval --json "path:$root#nixosConfigurations.wodan.config.home-manager.users.david.home.packages" \
    --apply 'map (package: package.pname or package.name)' |
    jq -e 'index("ksnip") != null' >/dev/null

cat >"$tmp/flake.nix" <<EOF
{
  inputs.nixcfg.url = "path:$root";

  outputs = {nixcfg, ...}: {
    homeConfigurations."mimir2" = nixcfg.lib.mkMimir2 {
      extraHomeModules = [{home.sessionVariables.NIXCFG_EXTENSION_PROBE = "yes";}];
    };
    darwinConfigurations.loki = nixcfg.lib.mkLoki {
      extraHomeModules = [{home.sessionVariables.NIXCFG_EXTENSION_PROBE = "yes";}];
      extraDarwinModules = [{environment.variables.NIXCFG_EXTENSION_PROBE = "yes";}];
    };
    darwinConfigurations.workLoki = nixcfg.lib.mkLoki {
      username = "work";
      homeDirectory = "/Users/work-custom";
      hostname = "work-loki";
      extraHomeModules = [
        ({hostname, repoRoot, ...}: {
          home.sessionVariables.NIXCFG_EXTENSION_HOSTNAME = hostname;
          home.sessionVariables.NIXCFG_EXTENSION_REPO_ROOT = repoRoot;
        })
      ];
    };
    darwinConfigurations.derivedHome = nixcfg.lib.mkLoki {
      username = "alice";
    };
  };
}
EOF

if ! nix flake lock "path:$tmp" >"$tmp/lock.log" 2>&1; then
    cat "$tmp/lock.log" >&2
    exit 1
fi

test "$(nix eval --raw "path:$tmp#homeConfigurations.\"mimir2\".config.home.sessionVariables.NIXCFG_EXTENSION_PROBE")" = yes
test "$(nix eval --raw "path:$tmp#darwinConfigurations.loki.config.home-manager.users.david.home.sessionVariables.NIXCFG_EXTENSION_PROBE")" = yes
test "$(nix eval --raw "path:$tmp#darwinConfigurations.loki.config.environment.variables.NIXCFG_EXTENSION_PROBE")" = yes
test "$(nix eval --raw "path:$tmp#darwinConfigurations.workLoki.config.networking.hostName")" = work-loki
test "$(nix eval --raw "path:$tmp#darwinConfigurations.workLoki.config.system.primaryUser")" = work
test "$(nix eval --raw "path:$tmp#darwinConfigurations.workLoki.config.users.users.work.home")" = /Users/work-custom
test "$(nix eval --raw "path:$tmp#darwinConfigurations.workLoki.config.home-manager.users.work.home.homeDirectory")" = /Users/work-custom
test "$(nix eval --raw "path:$tmp#darwinConfigurations.workLoki.config.home-manager.users.work.home.sessionVariables.NIXCFG_EXTENSION_HOSTNAME")" = work-loki
test "$(nix eval --raw "path:$tmp#darwinConfigurations.workLoki.config.home-manager.users.work.home.sessionVariables.NIXCFG_EXTENSION_REPO_ROOT")" = /Users/work-custom/nixcfg
test "$(nix eval --raw "path:$tmp#darwinConfigurations.derivedHome.config.home-manager.users.alice.home.homeDirectory")" = /Users/alice
