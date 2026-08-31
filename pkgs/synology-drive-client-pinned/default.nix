{
  lib,
  fetchurl,
  synology-drive-client,
  nautilus,
}: let
  version = "4.2.0-20058";
  baseUrl = "https://global.synologydownload.com/download/Utility/SynologyDriveClient";
  buildNumber = lib.last (lib.splitString "-" version);
  linuxSrc = fetchurl {
    url = "${baseUrl}/${version}/Ubuntu/Installer/synology-drive-client-${buildNumber}.x86_64.deb";
    hash = "sha256-QwAx/fWhLmVc5c/GuWTZtcvd3rzNvz+mtWYFRsuR+Z0=";
  };
  darwinSrc = fetchurl {
    url = "${baseUrl}/${version}/Mac/Installer/synology-drive-client-${buildNumber}.dmg";
    hash = "sha256-oFkyG1ip3+ff9hhRapD4a/Hj+ZrKcEWudIKr4OMtYJQ=";
  };
in
  synology-drive-client.overrideAttrs (old: {
    inherit version;
    src =
      if old.stdenv.hostPlatform.isDarwin or false
      then darwinSrc
      else linuxSrc;

    buildInputs =
      (old.buildInputs or [])
      ++ [
        nautilus
      ];

    autoPatchelfIgnoreMissingDeps = [
      "libQt5Pdf.so.5"
      "libnautilus-extension.so.4"
    ];
  })
