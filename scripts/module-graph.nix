{root ? ../.}: let
  flake = builtins.getFlake (toString root);
  inherit (flake.inputs.nixpkgs) lib;
  ownership = import ../policy/lib.nix {
    inherit lib den;
    root = flake.outPath;
  };
  localFile = file: let
    relative = ownership.relative file;
  in
    if relative != null && builtins.pathExists (flake.outPath + "/${relative}")
    then relative
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
  packages = origin: values:
    map (package: {
      name = package.pname or (lib.getName package);
      version = package.version or "";
      inherit origin;
    })
    values;
  homeSoftware = user: home: packages "home:${user}" home.home.packages;
  systemSoftware = name: system: let
    inherit (system) config;
    brew = category:
      map (entry: {
        name =
          if builtins.isString entry
          then entry
          else entry.name;
        version = "";
        origin = "homebrew:${category}";
      }) (config.homebrew.${category} or []);
  in {
    inherit name;
    packages =
      packages "system" config.environment.systemPackages
      ++ lib.concatLists (lib.mapAttrsToList homeSoftware (config.home-manager.users or {}))
      ++ brew "brews"
      ++ brew "casks";
  };
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
  inherit (flake.lib) den;
  policy = import ../policy {
    inherit lib den;
    root = flake.outPath;
  };
  references = value:
    if builtins.isList value
    then lib.concatMap references value
    else lib.optional (builtins.isAttrs value && !(lib.isDerivation value)) value;
  declaredImports = parent: value:
    if builtins.isList value
    then lib.concatMap (declaredImports parent) value
    else if builtins.isPath value
    then let
      file = localFile value;
    in
      lib.optional (file != null) {
        inherit file parent;
        disabled = false;
      }
    else if builtins.isAttrs value
    then declaredImports parent (value.imports or [])
    else [];
  # Resolved includes can be context functions; inspect safe flat membership only.
  composition = name: kind: entity: let
    members =
      [entity.aspect]
      ++ entity.hasAspect.allAspects
      ++ lib.concatMap (user: [user.aspect] ++ user.hasAspect.allAspects) (builtins.attrValues (entity.users or {}));
    nodes = lib.unique (lib.concatMap (node: let
      file = localFile (node.meta.file or "");
    in
      lib.optional (file != null && builtins.isString (node.name or null)) {
        inherit file;
        id = node.name;
      })
    members);
    ids = map (node: node.id) nodes;
    edges = lib.unique (lib.concatMap (id: let
      aspect = den.aspects.${id} or {};
    in
      map (child: [id child.name])
      (builtins.filter (child: builtins.elem (child.name or null) ids)
        (references (aspect.includes or []))))
    ids);
  in {inherit name kind nodes edges;};
in {
  schema = 1;
  software =
    lib.mapAttrsToList systemSoftware flake.nixosConfigurations
    ++ lib.mapAttrsToList systemSoftware flake.darwinConfigurations
    ++ lib.mapAttrsToList (name: home: {
      inherit name;
      packages = homeSoftware home.config.home.username home.config;
    })
    flake.homeConfigurations;
  wiring = collect wiring.graph;
  catalogue = lib.unique (lib.concatMap (aspect: let
    file = localFile (aspect.meta.file or "");
  in
    lib.optional (file != null) {
      inherit file;
      parent = null;
      disabled = false;
    }
    ++ lib.concatMap (class: declaredImports file (aspect.${class} or {})) ["nixos" "darwin" "homeManager"]) (builtins.attrValues den.aspects));
  policy = {
    inherit (policy) valid report;
    effective = import ../checks/architecture.nix {inherit flake;};
  };
  compositions =
    lib.concatMap (hosts:
      lib.mapAttrsToList (name: entity:
        composition name (
          if entity.class == "darwin"
          then "Darwin"
          else "NixOS"
        )
        entity)
      hosts)
    (builtins.attrValues den.hosts)
    ++ lib.concatMap (homes: lib.mapAttrsToList (name: composition name "Home Manager") homes) (builtins.attrValues den.homes);
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
