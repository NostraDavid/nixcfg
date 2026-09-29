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
      hash = "sha256-L5K5BOzzW2B+RNxcOSKRc69pxU8Rg+jXCfF3NUDNzzs=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-TOlEamjtwTICt2yEpH1m+z2tJ4e2RkyVIqEI+vnBxgg=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-39imkYvCpYoNvHJ/fkA5dm4yPfoV5MyrJQ1kCFHikNU=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-fMdzZ9C4TFAkOhEIvB9zZIaZIRJX1BS5F1QL+Gjmu4U=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported beads platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "beads";
    version = "1.3.0";

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
