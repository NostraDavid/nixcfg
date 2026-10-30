{
  autoPatchelfHook,
  fetchurl,
  gcc,
  lib,
  libxcb,
  libxkbcommon,
  makeDesktopItem,
  stdenvNoCC,
  vulkan-loader,
  wayland,
}: let
  assets = {
    x86_64-linux = {
      target = "linux-x86_64";
      hash = "sha256-2m97QPbEFsW03vjbz4t2Z30Cvk9LRdBqTWWHZoUOC0U=";
    };
    aarch64-linux = {
      target = "linux-aarch64";
      hash = "sha256-M235p/7CWbFKDfYwWLRfniLGFzBdEjrj+XE0hq8Ge14=";
    };
    aarch64-darwin = {
      target = "macos-aarch64";
      hash = "sha256-fNeD1s2Y4FDXy0O8Q9f6zDh9MAtbXpPHN2WWtdhycjE=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  desktop = makeDesktopItem {
    name = "herdr-app";
    desktopName = "Herdr (official)";
    comment = "Terminals and coding agents that keep running";
    exec = "herdr-app";
    icon = "herdr-app";
    categories = ["Development"];
    startupWMClass = "herdr-app";
  };
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "herdr-app";
    version = "0.1.9";
    src = fetchurl {
      url = "https://releases.herdr.dev/app/${finalAttrs.version}/herdr-app-${asset.target}.tar.gz";
      inherit (asset) hash;
    };
    sourceRoot = ".";
    nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [libxcb libxkbcommon gcc.cc.lib];
    runtimeDependencies = lib.optionals stdenvNoCC.hostPlatform.isLinux [vulkan-loader wayland];
    dontFixup = stdenvNoCC.hostPlatform.isDarwin;
    installPhase = ''
      runHook preInstall
      ${
        if stdenvNoCC.hostPlatform.isDarwin
        then ''
          mkdir -p "$out/Applications" "$out/bin"
          cp -R Herdr.app "$out/Applications/Herdr Official.app"
          ln -s "$out/Applications/Herdr Official.app/Contents/MacOS/Herdr" "$out/bin/herdr-app"
        ''
        else ''
          install -Dm755 herdr-app/herdr-app "$out/bin/herdr-app"
          install -Dm644 herdr-app/herdr-app.svg "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
          mkdir -p "$out/share/applications"
          ln -s ${desktop}/share/applications/herdr-app.desktop "$out/share/applications/herdr-app.desktop"
        ''
      }
      runHook postInstall
    '';
    doInstallCheck = stdenvNoCC.hostPlatform.isLinux;
    installCheckPhase = lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
      patchelf --print-rpath "$out/bin/herdr-app" | grep -F '${vulkan-loader}/lib'
      patchelf --print-rpath "$out/bin/herdr-app" | grep -F '${wayland}/lib'
    '';
    meta = {
      description = "Official Herdr desktop app for terminals and coding agents";
      homepage = "https://github.com/herdrdev/herdr-app";
      license = lib.licenses.asl20;
      mainProgram = "herdr-app";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
