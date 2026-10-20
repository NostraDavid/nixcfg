{
  inputs,
  packageSets,
  self,
}: {
  hostModules ? [
    ../hosts
  ],
  lokiSpec ? {},
  mimir2Spec ? {},
}: let
  inherit (inputs.nixpkgs) lib;
  directories = builtins.readDir ../features;
  features =
    map (name: ../features + "/${name}/default.nix")
    (builtins.filter (name: directories.${name} == "directory") (builtins.attrNames directories));
  profiles = lib.filesystem.listFilesRecursive ../profiles;
  evaluated = lib.evalModules {
    specialArgs = {
      inherit inputs packageSets self lokiSpec mimir2Spec;
      constructors = import ./constructors.nix {
        inherit inputs packageSets;
        den = evaluated.config.den;
      };
    };
    modules =
      [
        inputs.den.flakeModule
        inputs.den.flakeOutputs.flake
        inputs.den.flakeOutputs.all
        ({den, ...}: {
          den.systems = [
            "x86_64-linux"
            "aarch64-darwin"
          ];
          den.default.includes = [
            den.aspects.nixos-base
          ];
        })
      ]
      ++ features ++ profiles ++ hostModules;
  };
  policy = import ../policy {
    inherit lib;
    den = evaluated.config.den;
    root = ../.;
  };
in {
  inherit (evaluated.config) den;
  flake = assert policy.valid || throw "Architecture policy failed: ${builtins.toJSON policy.report}"; evaluated.config.flake;
}
