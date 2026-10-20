{
  lib,
  root,
  den ? null,
}: let
  prefix = toString root + "/";
  relative = file: let
    label = builtins.head (lib.splitString "#" (builtins.head (lib.splitString ", via option " (toString file))));
    # Den labels inline class modules by aspect identity; recover their actual definition source.
    synthetic = builtins.match "(nixos|darwin|homeManager)@([^/:]+).*" label;
    aspectName =
      if synthetic == null
      then null
      else builtins.elemAt synthetic 1;
    path =
      if den != null && aspectName != null && den.aspects ? ${aspectName}
      then den.aspects.${aspectName}.meta.file or label
      else label;
  in
    if lib.hasPrefix prefix path
    then
      lib.removePrefix prefix (
        if builtins.pathExists (path + "/default.nix")
        then path + "/default.nix"
        else path
      )
    else null;
  owner = file: let
    path = relative file;
    parts =
      if path == null
      then []
      else lib.splitString "/" path;
    area =
      if parts == []
      then null
      else builtins.head parts;
    name =
      if builtins.length parts < 2
      then null
      else builtins.elemAt parts 1;
  in
    if path == null
    then null
    else if path == "flake.nix"
    then {
      kind = "infrastructure";
      id = "nix";
      inherit path;
    }
    else if area == "features"
    then {
      kind = "feature";
      id = "features/${name}";
      inherit path;
    }
    else if area == "profiles"
    then {
      kind = "profile";
      id = "profiles/${name}";
      inherit path;
    }
    else if path == "hosts/default.nix"
    then {
      kind = "infrastructure";
      id = "hosts";
      inherit path;
    }
    else if
      area
      == "hosts"
      && builtins.length parts >= 4
      && builtins.elem name [
        "physical"
        "virtual"
      ]
    then {
      kind = "host";
      id = lib.concatStringsSep "/" (lib.take 3 parts);
      inherit path;
    }
    else if
      builtins.elem area [
        "nix"
        "policy"
      ]
    then {
      kind = "infrastructure";
      id = area;
      inherit path;
    }
    else {
      kind = "unknown";
      id = path;
      inherit path;
    };
  violation = rule: source: target: message: {inherit rule source target message;};
  allowed = from: to:
    from.kind
    == "infrastructure"
    || to.kind == "infrastructure"
    || from.id == to.id
    || (from.kind
      == "host"
      && builtins.elem to.kind [
        "feature"
        "profile"
      ])
    || (from.kind
      == "profile"
      && builtins.elem to.kind [
        "feature"
        "profile"
      ])
    || (from.kind == "feature" && to.kind == "feature");
  format = report: lib.concatMapStringsSep "\n" (v: "${v.rule}: ${v.source} -> ${v.target}: ${v.message}") report;
in {
  inherit relative owner violation allowed format;
}
