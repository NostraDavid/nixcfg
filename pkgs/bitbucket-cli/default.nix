{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-ZlRzfyWG4nYTjf0xAUyueIpNV1xQXklFKcCM6pZZfts=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-ljb61YVmHbmAGHhktAJmRPBiK1SOXfe8gupbj1N2CaI=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-SkuucmHsLURktKNh3MGy1rCGBN1iUJBC/pJm2KoRguc=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-QNkEnKVD3n/P/nKqvoBG1MKljJzTAOF+FOkS4kJc9rM=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.32.1";

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
