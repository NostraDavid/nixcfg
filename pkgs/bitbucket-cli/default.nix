{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-Se/rQ1pu2CGpMbkQ32Ubg1GQmbM1Gbg1OHech5Qcq9Y=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-Li98mmecFgt8bkh6Dc/SL1M9Qge03PnhnQizB6o+D3Q=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-myVsAoQ6IbqzCVd4VTj81R1pDDn/vl2AUiGmAqb2Iz4=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-zUf/UrbkhXW75Omer3FPvMNWCh8V9T6sQTCWfsbKo94=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.33.1";

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
