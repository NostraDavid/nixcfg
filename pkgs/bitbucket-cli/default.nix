{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-TTXjrP1fDGJTZnSJx/JjpkFOHKVYKFytRc14f/Zoniw=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-niEPWy2l5pSrkcu8uLGxkEQhL7kThg4AenbXq0uLLNs=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-jJQooXjcPLzduEBH3Z/0+UTOjb2NoRr6m6t5R/m61/g=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-eBy9EA/ESBg9Oz0Z8FUMTnRgbMlJGosHDaQl+064piM=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.33.0";

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
