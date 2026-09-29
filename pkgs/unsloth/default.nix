{
  appimageTools,
  fetchurl,
  lib,
}: let
  pname = "unsloth";
  version = "0.1.900-beta";
  src = fetchurl {
    url = "https://github.com/unslothai/unsloth/releases/download/v${version}/Unsloth-Desktop-Linux.AppImage";
    hash = "sha256-mjwd+4CENrMcwdxtZbrxUqucIexNqUyBp908Ekr+zZQ=";
  };
  contents = appimageTools.extractType2 {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
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
