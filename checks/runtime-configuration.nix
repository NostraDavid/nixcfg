let
  flake = builtins.getFlake (toString ../.);
  inherit (flake.inputs.nixpkgs) lib;
  drvPaths = lib.mapAttrs (_: package: package.drvPath);
in {
  nixos = lib.mapAttrs (_: host: host.config.system.build.toplevel.drvPath) flake.nixosConfigurations;
  darwin = lib.mapAttrs (_: host: host.config.system.build.toplevel.drvPath) flake.darwinConfigurations;
  packages = drvPaths (lib.filterAttrs (name: _: !(lib.hasSuffix "-image" name)) flake.packages.x86_64-linux);
  # These outputs require realization by design; their explicit checks build them.
  checks = drvPaths (lib.filterAttrs (name: _: !(lib.hasSuffix "-image" name)) flake.checks.x86_64-linux);
}
