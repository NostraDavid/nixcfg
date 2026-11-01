{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  assets = {
    x86_64-linux = {
      target = "linux-x86_64";
      hash = "sha256-WNaGEXbcb+kFtYiA1b/weplZvmE6mOXWa0WDsEts+kU=";
    };
    aarch64-linux = {
      target = "linux-aarch64";
      hash = "sha256-tlcxN9cLr/JPs0bJV6mHmva9xMZBGIzfnkensqZ3vJI=";
    };
    aarch64-darwin = {
      target = "macos-aarch64";
      hash = "sha256-aY2PDET05LFf7BdNUqOdV6AUz9ca3e1EtToHU7Rp0P0=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "herdr-core";
    version = "0.1.16";
    src = fetchurl {
      url = "https://releases.herdr.dev/core/${finalAttrs.version}/herdr-core-${asset.target}.tar.gz";
      inherit (asset) hash;
    };
    sourceRoot = ".";
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 herdr-core "$out/bin/herdr-core"
      ln -s herdr-core "$out/bin/hc"
      runHook postInstall
    '';
    meta = {
      description = "Terminal and agent backend for Herdr";
      homepage = "https://github.com/herdrdev/herdr-core";
      license = lib.licenses.asl20;
      mainProgram = "herdr-core";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
