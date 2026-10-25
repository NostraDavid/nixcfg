{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  unzip,
}: let
  pname = "orca-ide";
  version = "1.4.240";
  assets = {
    x86_64-linux = {
      name = "orca-linux.AppImage";
      hash = "sha256-+pyWAWSHAg7lGy+ImuhJX8STSjZm7pdnUy/wRXATtL4=";
    };
    aarch64-linux = {
      name = "orca-linux-arm64.AppImage";
      hash = "sha256-6Tv+DwyMGL/M2LQi+RuqF0Fh5PIRlKA1zDxhppShY3E=";
    };
    x86_64-darwin = {
      name = "Orca-${version}-mac.zip";
      hash = "sha256-8lHPva7V6G1wBljUKGk/wly8jTTe8i0MWDjJRmcR0TY=";
    };
    aarch64-darwin = {
      name = "Orca-${version}-arm64-mac.zip";
      hash = "sha256-osZ/WA6YI9MBJDZoS0J1A4F03Hljxu0XXEKF5y2UQGE=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };
  meta = {
    description = "Desktop workspace for coding agents, terminals, and browser automation";
    homepage = "https://github.com/stablyai/orca";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = lib.licenses.mit;
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
        cp -R extracted/Orca.app "$out/Applications/"
        test -x "$out/Applications/Orca.app/Contents/MacOS/Orca"
        makeWrapper "$out/Applications/Orca.app/Contents/MacOS/Orca" "$out/bin/orca-ide"
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
        install -Dm644 ${contents}/*.desktop "$out/share/applications/orca-ide.desktop"
        substituteInPlace "$out/share/applications/orca-ide.desktop" \
          --replace-fail 'Exec=AppRun' 'Exec=orca-ide'
        cp -r ${contents}/usr/share/icons "$out/share/icons"
      '';
    }
