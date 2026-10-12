{
  appimageTools,
  fetchurl,
  lib,
  nix-update-script,
}: let
  pname = "pi-desktop";
  version = "0.18.0";
  src = fetchurl {
    url = "https://github.com/vastsa/PI-Desktop/releases/download/v${version}/PI-Desktop-${version}-linux-x86_64.AppImage";
    hash = "sha256-CGVK8CtJY5fg0OSTz6Jwb13PXbRDoAeL8tIMHQKZCYE=";
  };
  contents = appimageTools.extractType2 {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    passthru.updateScript = nix-update-script {
      extraArgs = ["--version-regex" "^v(\\d+\\.\\d+\\.\\d+)$"];
    };

    extraInstallCommands = ''
      install -Dm644 ${contents}/pi-desktop.desktop "$out/share/applications/pi-desktop.desktop"
      substituteInPlace "$out/share/applications/pi-desktop.desktop" \
        --replace-fail 'Exec=AppRun' 'Exec=pi-desktop'
      cp -r ${contents}/usr/share/icons "$out/share/icons"
    '';

    meta = {
      description = "Desktop workspace for the Pi coding agent";
      homepage = "https://github.com/vastsa/PI-Desktop";
      changelog = "https://github.com/vastsa/PI-Desktop/releases/tag/v${version}";
      license = lib.licenses.lgpl3Only;
      mainProgram = pname;
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
