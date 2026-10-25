let
  flake = builtins.getFlake (toString ../.);
  inherit (flake.inputs.nixpkgs) lib;
  withoutGraft = host:
    host.extendModules {
      modules = [({lib, ...}: {system.replaceDependencies.replacements = lib.mkForce [];})];
    };
  drvPaths = lib.mapAttrs (_: package: package.drvPath);
in {
  nixos = lib.mapAttrs (_: host: let
    replacements = host.config.system.replaceDependencies.replacements;
  in
    assert replacements != [];
    assert lib.all (r: builtins.stringLength (toString r.oldDependency) == builtins.stringLength (toString r.newDependency)) replacements; {
      baseDrvPath = (withoutGraft host).config.system.build.toplevel.drvPath;
      replacementCount = builtins.length replacements;
    })
  flake.nixosConfigurations;
  darwin = lib.mapAttrs (_: host: host.config.system.build.toplevel.drvPath) flake.darwinConfigurations;
  packages = drvPaths (lib.filterAttrs (name: _: !(lib.hasSuffix "-image" name)) flake.packages.x86_64-linux);
  # These outputs require realization by design; their explicit checks build them.
  checks = drvPaths (lib.filterAttrs (name: _: name != "brotli-graft" && !(lib.hasSuffix "-image" name)) flake.checks.x86_64-linux);
}
