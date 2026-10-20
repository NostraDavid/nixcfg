{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-CK/wtumuGW54f2JhCcfoZUiyxV1K/GktiMkp5WLYh38=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-yzOtMJpWdJ7ltMmja5Vzgc3Vo4lphE1fQ+tidL4Vd1I=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-pkkSumGrQvmG/kzDifOlOuTMN97Z8hTtTiVqeiGiYNw=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-bQxjZsPrCzSze5+q9k/GJ6VBTQ+BbNRbFKAGvpkEhQA=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.35.1";

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
