{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenvNoCC,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-MhlEOpc0uJuT+xbujWWER1n6GzzTzxOcYGtzU8+wcVw=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-w7MscabAzWNYoSwoJysX5oGNuZHaGS+H31IznCIuQjo=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-E73bC0d0UD2X1X6UIErMK3xrd1/swi+ji8G4MXGOI00=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-UIuoB5luK5yZLFOKb0BfL8fS4Wz4tOWw0b+f6GA2cAc=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported beads platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "beads";
    version = "1.3.1";

    src = fetchurl {
      url = "https://github.com/gastownhall/beads/releases/download/v${finalAttrs.version}/beads_${finalAttrs.version}_${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];
    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted
      install -Dm755 extracted/bd "$out/bin/bd"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "Dependency-aware issue tracker for coding agents";
      homepage = "https://github.com/gastownhall/beads";
      changelog = "https://github.com/gastownhall/beads/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "bd";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
