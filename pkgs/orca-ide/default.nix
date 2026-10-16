{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  unzip,
}: let
  pname = "orca-ide";
  version = "1.4.227";
  assets = {
    x86_64-linux = {
      name = "orca-linux.AppImage";
      hash = "sha256-Mgrfi8p01AhqMyU5OlknWw82kEbvZCKdLAa/DBcxW4w=";
    };
    aarch64-linux = {
      name = "orca-linux-arm64.AppImage";
      hash = "sha256-RSPsmp14JX4KZnS9FWyHJQe5WTONXOfxAmyYluxgh7E=";
    };
    x86_64-darwin = {
      name = "Orca-${version}-mac.zip";
      hash = "sha256-Ofp9JPcGZZCygIXfJpMj/FdkjiL55yms4lYVl/A3tWM=";
    };
    aarch64-darwin = {
      name = "Orca-${version}-arm64-mac.zip";
      hash = "sha256-fTYd0Xd+LliS0M0eis1+bYyN5lRGRMApolb5aR1cvbk=";
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
