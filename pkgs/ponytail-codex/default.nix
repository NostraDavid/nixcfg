{
  lib,
  runCommand,
  src,
}: let
  version = "4.10.0";
in
  (runCommand "ponytail-codex-${version}" {} ''
    mkdir -p "$out"
    cp -R --no-preserve=mode,ownership ${src}/. "$out/"
    chmod -R u+w "$out"
  '').overrideAttrs (_: {
    inherit version;
    passthru.updateSkipReason = "bundled with the ponytail-skills flake input";
    meta = {
      description = "Ponytail Codex plugin with skills and lifecycle hooks";
      homepage = "https://github.com/DietrichGebert/ponytail";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  })
