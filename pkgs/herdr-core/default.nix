{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  assets = {
    x86_64-linux = {
      target = "linux-x86_64";
      hash = "sha256-6dur3q0M4M495RtvVMyVSe/tu0Gy+ESLaTKrDRRCND4=";
    };
    aarch64-linux = {
      target = "linux-aarch64";
      hash = "sha256-Gc72ouUvFMIsS28/2vGkYtLa/HjosD+rv61bBjR3o3A=";
    };
    aarch64-darwin = {
      target = "macos-aarch64";
      hash = "sha256-ylJDKdLgYwIZVQBV3McfQqr9hfujVuDVQ9b1EkRIeXA=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "herdr-core";
    version = "0.1.14";
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
