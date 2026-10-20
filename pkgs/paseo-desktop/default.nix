{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  unzip,
}: let
  pname = "paseo-desktop";
  version = "0.12.0";
  assets = {
    x86_64-linux = {
      name = "Paseo-x86_64.AppImage";
      hash = "sha256-0JXX+u/wo7w+ECIMCib43TxpIUeh/rj0zU7LHW53clQ=";
    };
    x86_64-darwin = {
      name = "Paseo-${version}-x64.zip";
      hash = "sha256-rrfLxAxgKuGxIN8mRW5vwkuSuuI3O9nij3GxMjPZWYs=";
    };
    aarch64-darwin = {
      name = "Paseo-${version}-arm64.zip";
      hash = "sha256-6rebFWxu6l5fRHJTO2ZySgopdPZydFwgJetZp1+CnUE=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/getpaseo/paseo/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };
  meta = {
    description = "Desktop and CLI interface for local and remote coding agents";
    homepage = "https://github.com/getpaseo/paseo";
    changelog = "https://github.com/getpaseo/paseo/releases/tag/v${version}";
    license = lib.licenses.asl20;
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
      nativeBuildInputs = [unzip makeWrapper];
      installPhase = ''
        runHook preInstall
        unzip -q "$src" -d extracted
        mkdir -p "$out/Applications" "$out/bin"
        cp -R extracted/Paseo.app "$out/Applications/"
        test -x "$out/Applications/Paseo.app/Contents/MacOS/Paseo"
        makeWrapper "$out/Applications/Paseo.app/Contents/MacOS/Paseo" "$out/bin/paseo-desktop"
        makeWrapper "$out/Applications/Paseo.app/Contents/Resources/bin/paseo" "$out/bin/paseo"
        runHook postInstall
      '';
    }
  else let
    contents = appimageTools.extractType2 {inherit pname version src;};
  in
    appimageTools.wrapType2 {
      inherit pname version src meta;
      nativeBuildInputs = [makeWrapper];
      extraInstallCommands = ''
        test -s ${contents}/resources/app.asar
        install -Dm644 ${contents}/Paseo.desktop "$out/share/applications/Paseo.desktop"
        substituteInPlace "$out/share/applications/Paseo.desktop" \
          --replace-fail 'Exec=AppRun' 'Exec=paseo-desktop'
        cp -r ${contents}/usr/share/icons "$out/share/icons"
        # The bundled CLI must enter the same FHS environment as the desktop app.
        makeWrapper "$out/bin/paseo-desktop" "$out/bin/paseo" \
          --set ELECTRON_RUN_AS_NODE 1 \
          --set PASEO_NODE_ENV production \
          --set PASEO_CLI "$out/bin/paseo" \
          --add-flags '--disable-warning=DEP0040 ${contents}/resources/app.asar.unpacked/dist/daemon/node-entrypoint-runner.js node-script ${contents}/resources/app.asar/node_modules/@getpaseo/cli/dist/index.js'
      '';
    }
