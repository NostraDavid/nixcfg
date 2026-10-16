{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
}: let
  pname = "kandev";
  version = "0.97.0";
  assets = {
    x86_64-linux = {
      name = "kandev-desktop-linux-x64-Kandev_${version}_amd64.AppImage";
      hash = "sha256-COKMW92ZgT2SxRzXgatLbmWpwZr5goFhSmy2Y6YcNs8=";
    };
    aarch64-linux = {
      name = "kandev-desktop-linux-arm64-Kandev_${version}_aarch64.AppImage";
      hash = "sha256-r2n2IHGrl2EJOcCsY/us9fo08CJeeKWUfIqpuV542zw=";
    };
    x86_64-darwin = {
      name = "kandev-desktop-macos-x64-Kandev.app.tar.gz";
      hash = "sha256-CFn01F2FMMpZqI0kte8H8VEcyQHG/S4iididyJMZRuk=";
    };
    aarch64-darwin = {
      name = "kandev-desktop-macos-arm64-Kandev.app.tar.gz";
      hash = "sha256-o+Hv3XG5GhcM3Gaaywqf+K+4nU6Abd1JZe/5cIMfTDs=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/kdlbs/kandev/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };
  meta = {
    description = "Desktop Kanban and development environment for coding agents";
    homepage = "https://github.com/kdlbs/kandev";
    changelog = "https://github.com/kdlbs/kandev/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    mainProgram = pname;
    platforms = builtins.attrNames assets;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
in
  if stdenvNoCC.hostPlatform.isDarwin
  then
    stdenvNoCC.mkDerivation {
      inherit pname version src meta;
      dontUnpack = true;
      dontBuild = true;
      dontFixup = true;
      nativeBuildInputs = [makeWrapper];
      installPhase = ''
        runHook preInstall
        mkdir extracted
        tar -xzf "$src" -C extracted
        mkdir -p "$out/Applications" "$out/bin"
        cp -R extracted/Kandev.app "$out/Applications/"
        test -x "$out/Applications/Kandev.app/Contents/MacOS/kandev-desktop"
        makeWrapper "$out/Applications/Kandev.app/Contents/MacOS/kandev-desktop" "$out/bin/kandev"
        runHook postInstall
      '';
    }
  else let
    contents = appimageTools.extractType2 {inherit pname version src;};
  in
    appimageTools.wrapType2 {
      inherit pname version src meta;
      extraInstallCommands = ''
        test -x ${contents}/usr/bin/kandev-desktop
        install -Dm644 ${contents}/usr/share/applications/Kandev.desktop "$out/share/applications/Kandev.desktop"
        substituteInPlace "$out/share/applications/Kandev.desktop" \
          --replace-fail 'Exec=kandev-desktop' 'Exec=kandev'
        cp -r ${contents}/usr/share/icons "$out/share/icons"
      '';
    }
