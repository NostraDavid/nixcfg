{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-MggB3VTThWwBNDdd8mFCKnhpV5xzCj46P2qXpbKjVOk=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-QxnVmN7MPDPYYhLwYQjHB4Wfbe/dk+S1DmZt4j89wf4=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-baLkt8JHY4AbSav3ZtcSD1sSFG0ejsaan0s2AVr3w5g=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-uppQocE43tSG84KN/mc5qeIj2wBlzsvMUcVy05hyAeM=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.37.0";

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
