{
  appimageTools,
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}: let
  pname = "t3code";
  version = "0.1.4";
  linuxHash = "sha256-efrmBW3Spa8lAWhGfVF1zxMb2M3yFqRXAZYqlijlw+k=";
  darwinHash = "sha256-10WNb4M79ppRtkjIylW9hDwYoH8Wh2cySPsZQN7rjrY=";
  src = fetchurl (
    if stdenvNoCC.hostPlatform.isDarwin
    then {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-arm64.zip";
      hash = darwinHash;
    }
    else {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
      hash = linuxHash;
    }
  );
  meta = {
    description = "T3 Code desktop interface for coding agents";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = ["x86_64-linux" "aarch64-darwin"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
in
  if stdenvNoCC.hostPlatform.isDarwin
  then
    stdenvNoCC.mkDerivation {
      inherit pname version src meta;
      nativeBuildInputs = [unzip];
      dontUnpack = true;
      dontFixup = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/Applications" "$out/bin"
        unzip -q "$src" -d "$out/Applications"
        test -x "$out/Applications/T3 Code (Beta).app/Contents/MacOS/T3 Code (Beta)"
        ln -s "$out/Applications/T3 Code (Beta).app/Contents/MacOS/T3 Code (Beta)" "$out/bin/t3code"
        runHook postInstall
      '';
    }
  else let
    contents = appimageTools.extractType2 {inherit pname version src;};
  in
    appimageTools.wrapType2 {
      inherit pname version src meta;

      extraInstallCommands = ''
        install -Dm644 ${contents}/t3code.desktop "$out/share/applications/t3code.desktop"
        substituteInPlace "$out/share/applications/t3code.desktop" \
          --replace-fail 'Exec=AppRun' 'Exec=t3code'
        cp -r ${contents}/usr/share/icons "$out/share/icons"
      '';
    }
