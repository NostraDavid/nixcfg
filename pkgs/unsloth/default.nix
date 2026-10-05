{
  appimageTools,
  coreutils,
  fetchurl,
  lib,
  makeWrapper,
  sqlite,
  writeShellScript,
}: let
  pname = "unsloth";
  version = "0.1.902-beta";
  src = fetchurl {
    url = "https://github.com/unslothai/unsloth/releases/download/v${version}/Unsloth-Desktop-Linux.AppImage";
    hash = "sha256-X8ANQbcdkTFLEo8+bc4S0Kn/T+2eGBHkAu84oraueh4=";
  };
  contents = appimageTools.extractType2 {inherit pname version src;};
  initializeSettings = writeShellScript "unsloth-initialize-settings" ''
    set -eu
    umask 077
    ${coreutils}/bin/mkdir -p "$HOME/.unsloth/studio"
    ${sqlite}/bin/sqlite3 -bail -cmd '.timeout 5000' \
      "$HOME/.unsloth/studio/studio.db" < ${./settings.sql}
  '';
in
  appimageTools.wrapType2 {
    inherit pname version src;

    nativeBuildInputs = [makeWrapper];
    extraPkgs = pkgs: [pkgs.nghttp2.lib];

    extraInstallCommands = ''
      mv "$out/bin/unsloth" "$out/bin/unsloth-unwrapped"
      makeWrapper "$out/bin/unsloth-unwrapped" "$out/bin/unsloth" \
        --run '${initializeSettings} || exit $?'
      install -Dm644 ${contents}/usr/share/applications/Unsloth.desktop "$out/share/applications/unsloth.desktop"
      substituteInPlace "$out/share/applications/unsloth.desktop" \
        --replace-fail 'Exec=unsloth-studio %u' 'Exec=unsloth %u' \
        --replace-fail 'Categories=' 'Categories=Science;Education;'
      cp -r ${contents}/usr/share/icons "$out/share/icons"
    '';

    meta = {
      description = "Unsloth Desktop AI model training and inference app";
      homepage = "https://github.com/unslothai/unsloth";
      changelog = "https://github.com/unslothai/unsloth/releases/tag/v${version}";
      license = lib.licenses.agpl3Only;
      mainProgram = "unsloth";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
