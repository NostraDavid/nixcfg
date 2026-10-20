{root ? ../.}: let
  flake = builtins.getFlake (toString root);
  inherit (flake.inputs.nixpkgs) lib;
  source = toString flake.outPath + "/";
  localFile = file: let
    path = builtins.head (lib.splitString ", via option " file);
    relative = lib.removePrefix source path;
  in
    if lib.hasPrefix source path && builtins.pathExists path
    then
      if builtins.pathExists (flake.outPath + "/${relative}/default.nix")
      then relative + "/default.nix"
      else relative
    else null;
  walk = parent: inheritedDisabled: node: let
    file = localFile node.file;
    owner =
      if file == null
      then parent
      else file;
    disabled = inheritedDisabled || node.disabled;
  in
    lib.optional (file != null) {
      inherit file parent disabled;
    }
    ++ lib.concatMap (walk owner disabled) node.imports;
  collect = graph: lib.unique (lib.concatMap (walk null false) graph);
  # Expose embedded Home Manager graphs only in this diagnostic evaluation.
  capture = {
    lib,
    extendModules,
    ...
  }: {
    options.nixcfgDiagnostics.moduleGraph = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      default = (extendModules {}).graph;
    };
  };
  systemGraph = name: kind: system: let
    extended = system.extendModules {
      modules = lib.optional (system.config ? home-manager) {
        home-manager.sharedModules = [capture];
      };
    };
  in {
    inherit name kind;
    system = collect extended.graph;
    home = lib.mapAttrs (_: home: collect home.nixcfgDiagnostics.moduleGraph) (extended.config.home-manager.users or {});
  };
  parts = flake.inputs.flake-parts;
  # Capture the actual flake entry point rather than duplicating its imports.
  wiring = (import (flake.outPath + "/flake.nix")).outputs (flake.inputs
    // {
      self = flake;
      flake-parts = parts // {lib = parts.lib // {mkFlake = parts.lib.evalFlakeModule;};};
    });
in {
  schema = 1;
  wiring = collect wiring.graph;
  machines =
    lib.mapAttrsToList (name: systemGraph name "NixOS") flake.nixosConfigurations
    ++ lib.mapAttrsToList (name: systemGraph name "Darwin") flake.darwinConfigurations
    ++ lib.mapAttrsToList (name: home: {
      inherit name;
      kind = "Home Manager";
      system = [];
      home.${home.config.home.username} = collect home.graph;
    })
    flake.homeConfigurations;
  variants = [
    {
      name = "mimir2 + workstation";
      kind = "optional";
      system = [];
      home.david = collect (flake.lib.mkMimir2 {extraHomeModules = [flake.modules.homeManager.workstation];}).graph;
    }
    (systemGraph "loki + workstation" "optional" (flake.lib.mkLoki {extraHomeModules = [flake.modules.homeManager.workstation];}))
  ];
}
