{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  unzip,
}: let
  pname = "agent-orchestrator";
  version = "0.14.2";
  assets = {
    x86_64-linux = {
      name = "agent-orchestrator-linux-x64.AppImage";
      hash = "sha256-Zt69nMWDm2w6mkbutTtm+d9H5uuXjoHYCR7eLwYtOw4=";
    };
    x86_64-darwin = {
      name = "agent-orchestrator-darwin-x64.zip";
      hash = "sha256-X6gD9AsI25sEFKww7mGpDh9M+zQEqQ4FrPkDNFw1H0Q=";
    };
    aarch64-darwin = {
      name = "agent-orchestrator-darwin-arm64.zip";
      hash = "sha256-n5ifstlu1EOTjBU2sEilhQAYMw+RbKqIB9bLWH2xdSk=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/OrchestratorInc/agent-orchestrator/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };
  meta = {
    description = "Desktop workspace for supervising teams of coding agents";
    homepage = "https://github.com/OrchestratorInc/agent-orchestrator";
    changelog = "https://github.com/OrchestratorInc/agent-orchestrator/releases/tag/v${version}";
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
        cp -R "extracted/Agent Orchestrator.app" "$out/Applications/"
        test -x "$out/Applications/Agent Orchestrator.app/Contents/MacOS/agent-orchestrator"
        makeWrapper "$out/Applications/Agent Orchestrator.app/Contents/MacOS/agent-orchestrator" "$out/bin/agent-orchestrator"
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
        install -Dm644 ${contents}/agent-orchestrator.desktop "$out/share/applications/agent-orchestrator.desktop"
        substituteInPlace "$out/share/applications/agent-orchestrator.desktop" \
          --replace-fail 'Exec=AppRun' 'Exec=agent-orchestrator'
        cp -r ${contents}/usr/share/icons "$out/share/icons"
      '';
    }
