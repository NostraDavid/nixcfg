{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  unzip,
}: let
  pname = "emdash";
  version = "1.2.9";
  assets = {
    x86_64-linux = {
      name = "emdash-x86_64.AppImage";
      hash = "sha256-7yDvIuDS3zvP29i0ox/OMe4B3RRrOjio0twc2AjRMC0=";
    };
    aarch64-linux = {
      name = "emdash-arm64.AppImage";
      hash = "sha256-y1npu7HGdcp4Jf/0jA6ogLt6tnFrqw6ZvCJA8+0680Q=";
    };
    x86_64-darwin = {
      name = "emdash-x64.zip";
      hash = "sha256-OVismtxt8ikBuQP6ncZQTBz7GTgDMwqYX6Mi4mi5g3A=";
    };
    aarch64-darwin = {
      name = "emdash-arm64.zip";
      hash = "sha256-6OEfEKCY6rCGl34iXDQQXW98fs9GNpuIiE5o1F1iMs4=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/generalaction/emdash/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };
  meta = {
    description = "Desktop environment for parallel coding agents and Git worktrees";
    homepage = "https://github.com/generalaction/emdash";
    changelog = "https://github.com/generalaction/emdash/releases/tag/v${version}";
    license = lib.licenses.asl20;
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
        cp -R extracted/Emdash.app "$out/Applications/"
        test -x "$out/Applications/Emdash.app/Contents/MacOS/Emdash"
        makeWrapper "$out/Applications/Emdash.app/Contents/MacOS/Emdash" "$out/bin/emdash" \
          --set TELEMETRY_ENABLED false
        runHook postInstall
      '';
    }
  else let
    contents = appimageTools.extractType2 {inherit pname version src;};
  in
    appimageTools.wrapType2 {
      inherit pname version src meta;
      profile = ''
        export TELEMETRY_ENABLED=false
      '';
      extraInstallCommands = ''
        test -s ${contents}/resources/app.asar
        install -Dm644 ${contents}/Emdash.desktop "$out/share/applications/Emdash.desktop"
        substituteInPlace "$out/share/applications/Emdash.desktop" \
          --replace-fail 'Exec=AppRun' 'Exec=emdash'
        cp -r ${contents}/usr/share/icons "$out/share/icons"
      '';
    }
