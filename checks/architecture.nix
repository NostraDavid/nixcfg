{
  root ? ../.,
  flake ? builtins.getFlake (toString root),
}: let
  inherit (flake.inputs.nixpkgs) lib;
  structural = import ../policy {
    inherit lib;
    inherit (flake.lib) den;
    root = flake.outPath;
  };
  homes =
    builtins.attrValues (lib.mapAttrs (_: home: home.config) flake.homeConfigurations)
    ++ lib.concatMap (system: builtins.attrValues (system.config.home-manager.users or {}))
    (builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations);
  configs = map (system: system.config) (builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations) ++ homes;
  homeSentinel = selected: config:
    (import ../policy/native.nix {
      inherit lib selected config;
      root = flake.outPath;
      graph = [];
      options = {};
      class = "homeManager";
    }).assertion;
  coverage =
    map (homeSentinel ["annotation" "mcp"]) homes
    ++ map (name: homeSentinel ["codex-browser"] flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "frigg" "bragi"];
  coverageFailures = builtins.filter (entry: !entry.assertion) coverage;
  failures = lib.concatMap (config: builtins.filter (entry: !entry.assertion) config.assertions) configs;
in {
  structure =
    if structural.valid
    then true
    else throw structural.assertion.message;
  coverage =
    if coverageFailures == []
    then true
    else throw (lib.concatMapStringsSep "\n" (entry: entry.message) coverageFailures);
  effective =
    if failures == []
    then true
    else throw (lib.concatMapStringsSep "\n" (entry: entry.message) failures);
}
