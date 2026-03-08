{
  appimageTools,
  fetchurl,
  lib,
}: let
  pname = "whatpulse";
  version = "6.0.1";

  src = fetchurl {
    # WhatPulse does not expose a stable Linux release URL on /downloads; pin the
    # versioned AppImage URL from https://whatpulse.org/releasenotes instead.
    url = "https://releases-dev.whatpulse.org/${version}/linux/whatpulse-linux-${version}_amd64.AppImage";
    hash = "sha256-osi0M0ZIQdS1s7HviclrVY0qdnDchGu/qX3kJY2GttQ=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -Dm644 ${appimageContents}/whatpulse.desktop $out/share/applications/whatpulse.desktop
      substituteInPlace $out/share/applications/whatpulse.desktop \
        --replace-fail 'Exec=whatpulse' 'Exec=${pname}'

      install -Dm644 ${appimageContents}/whatpulse.png $out/share/icons/hicolor/512x512/apps/whatpulse.png
    '';

    meta = {
      description = "Track keyboard, mouse, uptime and network usage";
      homepage = "https://whatpulse.org/";
      license = lib.licenses.unfree;
      mainProgram = pname;
      platforms = ["x86_64-linux"];
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    };
  }
