{
  appimageTools,
  fetchurl,
  lib,
}: let
  pname = "t3code";
  version = "0.0.45";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-q3sKhtHqZXzMFitgt3LGH3C8fIueJZtGk51Tuzj6oCo=";
  };
  contents = appimageTools.extractType2 {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -Dm644 ${contents}/t3code.desktop "$out/share/applications/t3code.desktop"
      substituteInPlace "$out/share/applications/t3code.desktop" \
        --replace-fail 'Exec=AppRun' 'Exec=t3code'
      cp -r ${contents}/usr/share/icons "$out/share/icons"
    '';

    meta = {
      description = "T3 Code desktop interface for coding agents";
      homepage = "https://t3.codes";
      changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
      license = lib.licenses.mit;
      mainProgram = pname;
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
