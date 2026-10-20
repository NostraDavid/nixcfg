{
  lib,
  den,
  root,
}: let
  inherit (import ./lib.nix {inherit lib root;}) owner allowed violation format;
  inherit (den) aspects;
  names = builtins.attrNames aspects;
  file = aspect: aspect.meta.file or "<anonymous>";
  owned = aspect: owner (file aspect);
  references = value:
    if builtins.isList value
    then lib.concatMap references value
    else if builtins.isAttrs value && !(lib.isDerivation value)
    then [value]
    else [];
  children = aspect: references (aspect.includes or []);
  entities =
    lib.concatMap builtins.attrValues (builtins.attrValues (den.hosts or {}))
    ++ lib.concatMap builtins.attrValues (builtins.attrValues (den.homes or {}));
  users = lib.concatMap (entity: builtins.attrValues (entity.users or {})) entities;
  edges =
    lib.concatMap (from: map (to: {inherit from to;}) (children from))
    (map (name: aspects.${name}) names);
  edgeViolations = lib.concatMap ({
    from,
    to,
  }: let
    a = owned from;
    b = owned to;
  in
    lib.optional (a != null && b != null && !(allowed a b))
    (violation "dependency-direction" a.path b.path "Features cannot include profiles or hosts."))
  edges;
  aspectViolations = lib.concatMap (name: let
    aspect = aspects.${name};
    source = owned aspect;
    opaque = builtins.filter (dependency:
      !(builtins.isAttrs dependency
        && dependency ? name
        && dependency ? meta
        && dependency.meta ? file
        && den.lib.aspects.isMeaningfulName dependency.name)) (lib.flatten (aspect.includes or []));
    classes = builtins.filter (class: aspect ? ${class}) ["nixos" "darwin" "homeManager"];
  in
    if source == null
    then []
    else
      lib.optional (source.kind == "unknown")
      (violation "unknown-owner" source.path name "Move the implementation into its responsibility directory.")
      ++ lib.optional (builtins.elem source.kind ["feature" "profile"] && opaque != [])
      (violation "opaque-include" source.path name "Feature and profile dependencies must be concrete named aspect references; dynamic selection belongs to inventory.")
      ++ lib.optional (source.kind == "profile" && classes != [])
      (violation "profile-implementation" source.path name "Profiles compose aspects; class implementations belong to features."))
  names;
  # Traverse authored references before Den deduplicates repeated includes.
  visit = stack: aspect: let
    key = aspect.name or (file aspect);
  in
    if builtins.elem key stack
    then lib.optional (owned aspect != null) (violation "include-cycle" (lib.concatStringsSep " -> " stack) key "Aspect includes form a cycle.")
    else lib.concatMap (visit (stack ++ [key])) (children aspect);
  cycleViolations = lib.concatMap (name: visit [] aspects.${name}) names;
  platformViolations = lib.concatMap (entity: let
    system = entity.system or entity.host.system;
    platform =
      if lib.hasSuffix "darwin" system
      then "darwin"
      else "linux";
  in
    lib.concatMap (aspect: let
      platforms = aspect.meta.platforms or null;
      source = owned aspect;
      validPlatforms = builtins.isList platforms && builtins.all (value: builtins.elem value ["linux" "darwin"]) platforms;
    in
      lib.optional (platforms != null && (!validPlatforms || !(builtins.elem platform platforms)))
      (violation "feature-platform" (
          if source == null
          then aspect.name
          else source.path
        )
        entity.name "The selected aspect does not support this platform."))
    entity.hasAspect.allAspects) (entities ++ users);
  report = lib.unique (edgeViolations ++ aspectViolations ++ cycleViolations ++ platformViolations);
  valid = report == [];
in {
  inherit report valid;
  assertion = {
    assertion = valid;
    message = "Architecture policy failed:\n${format report}";
  };
}
