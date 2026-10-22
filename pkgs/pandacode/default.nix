{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
}: let
  pname = "pandacode";
  version = "0.3.21";
  assets = {
    x86_64-linux = {
      name = "PandaCode-Linux-x86_64.AppImage";
      hash = "sha256-80m5iS4iD+fsqbjFHoU99rJWxP9csWZKkYmA6AMneIU=";
    };
    aarch64-linux = {
      name = "PandaCode-Linux-aarch64.AppImage";
      hash = "sha256-TuATkNljszwB9avn+Cfk7pUqustD36uyucVdlX0uleY=";
    };
    aarch64-darwin = {
      name = "PandaCode-macOS-arm64.app.tar.gz";
      hash = "sha256-VFiOPNadniF2Z9zhF5E1ALADi9nUrGjVjMIE2YeR/LU=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/aicodeking/pandacode/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };
  meta = {
    description = "Desktop workspace for coding agents";
    homepage = "https://github.com/aicodeking/pandacode";
    changelog = "https://github.com/aicodeking/pandacode/releases/tag/v${version}";
    license = {
      fullName = "PandaCode License (MIT with fork attribution requirement)";
      url = "https://github.com/aicodeking/pandacode/blob/v${version}/LICENSE";
      free = true;
    };
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
        cp -R extracted/PandaCode.app "$out/Applications/"
        test -x "$out/Applications/PandaCode.app/Contents/MacOS/pandacode"
        makeWrapper "$out/Applications/PandaCode.app/Contents/MacOS/pandacode" "$out/bin/pandacode"
        runHook postInstall
      '';
    }
  else let
    contents = appimageTools.extractType2 {inherit pname version src;};
  in
    appimageTools.wrapType2 {
      inherit pname version src meta;
      profile = ''
        # WebKit's DMA-BUF renderer fails to initialize EGL on NVIDIA.
        export WEBKIT_DISABLE_DMABUF_RENDERER=1
      '';
      extraInstallCommands = ''
        test -x ${contents}/usr/bin/pandacode
        install -Dm644 ${contents}/PandaCode.desktop "$out/share/applications/pandacode.desktop"
        cp -r ${contents}/usr/share/icons "$out/share/icons"
      '';
    }
