{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  unzip,
}: let
  pname = "superset";
  version = "2.0.0";
  assets = {
    x86_64-linux = {
      name = "superset-${version}-x86_64.AppImage";
      hash = "sha256-SFfx9iVQPQ2ASKxVAKfxkGLtJhzVwb54fMSoeb9ilsI=";
    };
    x86_64-darwin = {
      name = "Superset-${version}-mac.zip";
      hash = "sha256-IS0NHCIyUReqtxLqBGDLYWN8PJTjHtJknzlLGDzEIn8=";
    };
    aarch64-darwin = {
      name = "Superset-${version}-arm64-mac.zip";
      hash = "sha256-97sHmGOig2LrABQ08eqny7r8jMSgSFT/v64W9BBoVII=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/superset-sh/superset/releases/download/desktop-v${version}/${asset.name}";
    inherit (asset) hash;
  };
  meta = {
    description = "Desktop workspace for coding agents, terminals, and code review";
    homepage = "https://github.com/superset-sh/superset";
    changelog = "https://github.com/superset-sh/superset/releases/tag/desktop-v${version}";
    license = lib.licenses.elastic20;
    mainProgram = pname;
    platforms = builtins.attrNames assets;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
in
  if stdenvNoCC.hostPlatform.isDarwin
  then
    stdenvNoCC.mkDerivation {
      inherit pname version src meta;
      dontUnpack = true;
      dontBuild = true;
      dontFixup = true;
      nativeBuildInputs = [unzip makeWrapper];
      installPhase = ''
        runHook preInstall
        unzip -q "$src" -d extracted
        mkdir -p "$out/Applications" "$out/bin"
        cp -R extracted/Superset.app "$out/Applications/"
        test -x "$out/Applications/Superset.app/Contents/MacOS/Superset"
        makeWrapper "$out/Applications/Superset.app/Contents/MacOS/Superset" "$out/bin/superset"
        runHook postInstall
      '';
    }
  else let
    contents = appimageTools.extractType2 {inherit pname version src;};
  in
    appimageTools.wrapType2 {
      inherit pname version src meta;
      extraInstallCommands = ''
        test -s ${contents}/resources/app.asar
        install -Dm644 ${contents}/superset.desktop "$out/share/applications/superset.desktop"
        substituteInPlace "$out/share/applications/superset.desktop" \
          --replace-fail 'Exec=AppRun' 'Exec=superset'
        cp -r ${contents}/usr/share/icons "$out/share/icons"
      '';
    }
