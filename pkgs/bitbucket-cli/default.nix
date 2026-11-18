{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-63VF+Mjuq2RNIhkyBgEzfNZrjrx9LLyI2iK52hrJ0k0=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-zP8oiOAhLe6/ywiltqEQNldlDC0L3yJ0r/Tr9lRhFcA=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-X1wK5qkxQQDiPiqAuYWhNZFbG6UwOSIun9nrpa5OYS4=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-nxNJRQX/yw7gqZvXPhb7j1rB3a07xnOovZHUVBQ/zIc=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.40.2";

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
