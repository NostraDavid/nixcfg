{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-X8NlLco7595t2l5GT+c0JOrO5ZrMHeTwq1Oh4XiLhbc=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-EmynedghKNRq9zXyyxQt9C9cmeUaNiD10wfDpS+TlBM=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-3Am+ObqjrS8/evDXeIonDE8cNeJV0E4wo/gUm+nqF8s=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-y3aAFLq4tDRhd3232hEONep8+h8s0m+xbtNLqMxQi40=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.41.0";

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
