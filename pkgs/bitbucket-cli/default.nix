{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-U19EvEzh20VMUsWqN/K0g2NuhAPQcBg9cobJx3D+o14=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-kd7/wkOMA4Vdqt8M1u1Jo4OMbfoKRXQfZo6apCV/08Q=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-Gkl78srSfkgwLWagcVGS3u/FUuTcaZ2Ir+SeqQblSAw=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-wL5GuPAjkCXhzxV3rXB/BnWSFVRAAnNauBuFmGa6yOs=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.35.2";

    src = fetchurl {
      url = "https://github.com/avivsinai/bitbucket-cli/releases/download/v${finalAttrs.version}/bkt_${finalAttrs.version}_${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted
      install -Dm755 extracted/bkt "$out/bin/bkt"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "Bitbucket CLI for Bitbucket Cloud and Data Center";
      homepage = "https://github.com/avivsinai/bitbucket-cli";
      changelog = "https://github.com/avivsinai/bitbucket-cli/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "bkt";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
