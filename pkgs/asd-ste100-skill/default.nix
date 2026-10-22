{
  lib,
  python3,
  runCommand,
}: let
  # Use this repository's pin independently of a work flake's inputs.
  src = builtins.fetchTree (builtins.fromJSON (builtins.readFile ../../flake.lock)).nodes.asd-ste100-skill.locked;
in
  runCommand "asd-ste100-skill" {
    version = "unstable-${src.lastModifiedDate}-${src.shortRev}";
    nativeBuildInputs = [(python3.withPackages (ps: [ps.pyyaml]))];
    passthru.skillNames = ["asd-ste100"];
    meta = {
      description = "ASD-STE100 skill for unambiguous technical English";
      homepage = "https://github.com/danyuchn/asd-ste100-skill";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  } ''
    mkdir -p "$out/asd-ste100"
    cp -R ${src}/. "$out/asd-ste100/"
    chmod -R u+w "$out"
    python ${../../features/dotfiles/skill-descriptions.py} ${../../dotfiles/agents/descriptions.json} "$out"
    chmod +x "$out/asd-ste100/scripts/ste-lint.py"
    patchShebangs "$out/asd-ste100/scripts/ste-lint.py"
  ''
