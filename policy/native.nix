{
  lib,
  root,
  den ? null,
  graph,
  config,
  options,
  class,
  selected ? [],
  required ? [],
  expectedHome ? null,
}: let
  inherit (import ./lib.nix {inherit lib root den;}) owner allowed violation format;
  walk = parent: node:
    if node.disabled
    then []
    else let
      current = owner node.file;
      source =
        if current == null
        then parent
        else current;
      edges = lib.optional (parent != null && current != null) {
        from = parent;
        to = current;
      };
    in
      edges ++ lib.concatMap (walk source) node.imports;
  edges = lib.concatMap (walk null) graph;
  imports = lib.concatMap ({
    from,
    to,
  }:
    lib.optional (!(allowed from to))
    (violation "native-dependency-direction" from.path to.path "Native imports must respect the aspect boundaries.")
    ++ lib.optional (from.id != to.id && from.kind != "infrastructure" && to.kind == "feature" && !(lib.hasSuffix "/default.nix" to.path))
    (violation "private-feature-import" from.path to.path "Import the feature entrypoint instead of its implementation.")
    ++ lib.optional (to.kind == "unknown")
    (violation "unknown-native-owner" from.path to.path "The local module has no architecture owner."))
  edges;
  definitions = path: let
    option = lib.attrByPath path null options;
  in
    if option != null && option ? definitionsWithLocations
    then option.definitionsWithLocations
    else [];
  identityPaths =
    if class == "homeManager"
    then [
      [
        "home"
        "username"
      ]
      [
        "home"
        "homeDirectory"
      ]
      [
        "home"
        "stateVersion"
      ]
    ]
    else [
      [
        "networking"
        "hostName"
      ]
      [
        "system"
        "stateVersion"
      ]
      [
        "fileSystems"
      ]
    ];
  identity = lib.concatMap (path:
    lib.concatMap (definition: let
      source = owner definition.file;
    in
      lib.optional (source
        != null
        && builtins.elem source.kind [
          "feature"
          "profile"
        ])
      (violation "host-value-owner" source.path (lib.concatStringsSep "." path) "Identity, state version and device assignments belong to host definitions or their hardware.")) (definitions path))
  identityPaths;
  home = config.home or {};
  packages = home.packages or [];
  hasPackage = pname: builtins.any (pkg: lib.toLower (pkg.pname or (lib.getName pkg)) == pname) packages;
  servers =
    lib.attrByPath [
      "nixcfg"
      "mcp"
      "servers"
    ] {}
    config;
  localServers = lib.filterAttrs (_: server: server ? command) servers;
  homeFiles = home.file or {};
  homePath = home.homeDirectory or "";
  hasFeature = name: builtins.elem name selected;
  requiredServers = [
    "agent-memory"
    "chrome-devtools"
    "dbhub"
    "headroom"
    "nixos"
    "playwright"
    "qartez"
  ];
  stableServer = server: let
    prefix = "${homePath}/.local/bin/";
    relativeCommand = lib.removePrefix "${homePath}/" server.command;
  in
    lib.hasPrefix prefix server.command && homeFiles ? ${relativeCommand} && !(lib.hasInfix "/nix/store/" (builtins.toJSON server));
  mcp =
    lib.optional (hasFeature "mcp" && !(builtins.all (name: servers ? ${name}) requiredServers))
    (violation "required-mcp" homePath "MCP servers" "The selected MCP feature must deliver all local servers required for its platform.")
    ++ lib.optional (hasFeature "mcp" && !(lib.all (name: stableServer localServers.${name}) (builtins.attrNames localServers)))
    (violation "stable-mcp-command" homePath "MCP commands" "Every local server must use its installed stable launcher.");
  nativeCodex = lib.optional (hasFeature "codex-browser"
    && !(
      homeFiles ? ".local/bin/codex-mcp-node-repl"
      && homeFiles ? ".local/bin/cua-repl"
      && homeFiles ? ".local/bin/mcp-node-repl"
      && toString homeFiles.".local/bin/mcp-node-repl".source == toString homeFiles.".local/bin/codex-mcp-node-repl".source
    ))
  (violation "native-codex-mcp" homePath "Codex MCP" "Preserve the native launchers and route the shared Node REPL command to the Codex runtime.");
  expected =
    if expectedHome == null
    then []
    else
      lib.concatMap (name:
        lib.optional ((home.${name} or null) != expectedHome.${name})
        (violation "home-contract" homePath name "The evaluated home differs from its declared user contract.")) (builtins.attrNames expectedHome);
  effective = lib.optionals (class == "homeManager") (
    lib.optional (hasFeature "annotation" && !(hasPackage "pinta"))
    (violation "required-annotation" homePath "pinta" "The annotation feature must actually install Pinta.")
    ++ mcp
    ++ nativeCodex
    ++ expected
    ++ lib.optional (builtins.length (builtins.filter (pkg: (pkg.pname or "") == "chromium") packages) > 1)
    (violation "chromium-collision" homePath "chromium" "Only one interactive Chromium package may provide bin/chromium.")
  );
  requiredSelections = lib.concatMap (name:
    lib.optional (!(hasFeature name))
    (violation "required-aspect-selection" homePath name "The managed home must select this required capability."))
  required;
  report = lib.unique (imports ++ identity ++ effective ++ requiredSelections);
in {
  inherit report;
  valid = report == [];
  assertion = {
    assertion = report == [];
    message = "Architecture policy failed:\n${format report}";
  };
}
