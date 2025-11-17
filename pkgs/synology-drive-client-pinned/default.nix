{
  lib,
  fetchurl,
  synology-drive-client,
  qt5,
  nautilus,
}: let
  version = "4.0.1-17885";
  baseUrl = "https://global.synologydownload.com/download/Utility/SynologyDriveClient";
  buildNumber = lib.last (lib.splitString "-" version);
  linuxSrc = fetchurl {
    url = "${baseUrl}/${version}/Ubuntu/Installer/synology-drive-client-${buildNumber}.x86_64.deb";
    hash = "sha256-DMHqh8o0RknWTycANSbMpJj133/MZ8uZ18ytDZVaKMg=";
  };
  darwinSrc = fetchurl {
    url = "${baseUrl}/${version}/Mac/Installer/synology-drive-client-${buildNumber}.dmg";
    hash = "sha256-0rK7w4/RCv4qml+8XYPwLQmxHen3pB793Co4DvnDVuU=";
  };
in
  synology-drive-client.overrideAttrs (old: {
    inherit version;
    src =
      if old.stdenv.isDarwin or false
      then darwinSrc
      else linuxSrc;

    buildInputs =
      (old.buildInputs or [])
      ++ [
        qt5.qtwebengine
        nautilus
      ];

    autoPatchelfIgnoreMissingDeps = [
      "libQt5Pdf.so.5"
      "libnautilus-extension.so.4"
    ];
  })
