{
  appimageTools,
  fetchurl,
  lib,
}: let
  pname = "opencode-desktop";
  version = "2.1.0";
  src = fetchurl {
    url = "https://opencode.ai/files/bin/${version}/opencode-desktop-linux-x86_64.AppImage";
    hash = "sha256-kNwQGraIKnESZ1B1a65macd4+Er0vyRX5cqYePPeHxI=";
  };
  contents = appimageTools.extractType2 {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;
    profile = ''
      export OPENCODE_DISABLE_AUTOUPDATE=true
    '';
    extraInstallCommands = ''
      test -s ${contents}/resources/app.asar
      test -x ${contents}/resources/opencode-cli
      grep -Fx '${version}' ${contents}/resources/opencode-cli.version
      install -Dm644 ${contents}/ai.opencode.desktop.desktop \
        "$out/share/applications/ai.opencode.desktop.desktop"
      substituteInPlace "$out/share/applications/ai.opencode.desktop.desktop" \
        --replace-fail 'Exec=AppRun' 'Exec=opencode-desktop'
      cp -r ${contents}/usr/share/icons "$out/share/icons"
    '';
    meta = {
      description = "OpenCode v2 desktop client";
      homepage = "https://opencode.ai/v2/docs";
      license = lib.licenses.mit;
      mainProgram = "opencode-desktop";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
