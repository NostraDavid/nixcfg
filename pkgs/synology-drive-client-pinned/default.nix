{
  lib,
  fetchurl,
  synology-drive-client,
  nautilus,
}: let
  version = "4.2.1-20062";
  baseUrl = "https://global.synologydownload.com/download/Utility/SynologyDriveClient";
  buildNumber = lib.last (lib.splitString "-" version);
  linuxSrc = fetchurl {
    url = "${baseUrl}/${version}/Ubuntu/Installer/synology-drive-client-${buildNumber}.x86_64.deb";
    hash = "sha256-4LU72OLmZvvwgHObova5NYascIf13kuRvAE+ii38QPU=";
  };
  darwinSrc = fetchurl {
    url = "${baseUrl}/${version}/Mac/Installer/synology-drive-client-${buildNumber}.dmg";
    hash = "sha256-JWB7za62cytVMRNlJlhYeb8M5J1q8CgeNELB0AMHxE0=";
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
