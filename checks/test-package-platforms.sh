#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
nix eval --json "$root#packages.x86_64-linux" \
    --apply 'packages: builtins.mapAttrs (_: package: package.drvPath) packages' |
    jq -e '(["acli", "bend", "codex", "mdschema", "uv"] - keys) == []
        and (has("plocate-xnu") | not)' >/dev/null

cache=$(nix eval --json "$root#lib.cachePackageNames.x86_64-linux")
jq -e 'index("bend") != null and index("forgejo-lab-image") != null
    and index("acli") == null and index("uv") == null' <<<"$cache" >/dev/null

cd "$root"
nix eval --impure --json --expr '
  let
    flake = builtins.getFlake (toString ./.);
    sets = import ./nix/packages.nix { inherit (flake) inputs; };
    check = system: let
      pkgs = sets.pkgsFor system;
      inherit (pkgs) acli lib mdschema uv;
    in
      lib.all (lib.meta.availableOn pkgs.stdenv.hostPlatform) [ acli mdschema uv ]
      && lib.versionAtLeast acli.version "1.3.41-stable"
      && lib.versionAtLeast mdschema.version "0.16.0"
      && lib.versionAtLeast uv.version (if system == "x86_64-darwin" then "0.13.9" else "0.13.5")
      && (system == "x86_64-linux" -> (builtins.elem "mdschema" flake.lib.cachePackageNames.x86_64-linux)
        == (mdschema.drvPath != (sets.unstableFor system).mdschema.drvPath))
      && builtins.all (pkg: builtins.isString pkg.drvPath) [ acli mdschema uv ];
  in builtins.all check [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
' | jq -e . >/dev/null
echo 'Package platforms, Linux exports and bulk cache selection passed.'
