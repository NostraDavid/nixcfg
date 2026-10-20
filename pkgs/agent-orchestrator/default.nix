{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  unzip,
}: let
  pname = "agent-orchestrator";
  version = "0.14.3";
  assets = {
    x86_64-linux = {
      name = "agent-orchestrator-linux-x64.AppImage";
      hash = "sha256-WQdPYpO+co0INVusgnwQS6iHjNdpS4y0Mj41e/vCdfg=";
    };
    x86_64-darwin = {
      name = "agent-orchestrator-darwin-x64.zip";
      hash = "sha256-XgaEmVYHTKOFJCTb/pJ+BewOlpH5qKU6C3l/JKP7xRc=";
    };
    aarch64-darwin = {
      name = "agent-orchestrator-darwin-arm64.zip";
      hash = "sha256-Wqb0YaowS651MOcYsPLR7wYw5hJtkhk0gZUhnn1fQts=";
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
