{
  stdenvNoCC,
  lib,
  tamzen,
  bdf2sfd,
  fontforge,
}:
stdenvNoCC.mkDerivation {
  pname = "tamzen-otf";
  inherit (tamzen) src version;
  nativeBuildInputs = [bdf2sfd fontforge];
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/fonts/opentype"
    fontforge -lang py -script ${./convert.py}
    runHook postInstall
  '';
  passthru.updateSkipReason = "Font source follows nixpkgs.tamzen";
  meta = {
    description = "Tamzen bitmap programming font converted to OpenType";
    homepage = "https://github.com/sunaku/tamzen-font";
    license = lib.licenses.free;
    platforms = lib.platforms.all;
  };
}
