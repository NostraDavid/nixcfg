{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-6N1Xn+fEbTMkA47lN2sEwWWcfXMFXY7Z5u3SJelEISk=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-euIwXJZ63RnWWPqNdP/ClMMWAuu2l1eQ8mlD1/gyMhw=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-DUGnflo2jtuFwRdBH3HQOA0/sE9X2OdMt3/VVqMiiV8=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-VlWF8ybaJ5PemWdBZmQL4/+6VG1yPawIp6mXHoQZa3I=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.35.0";

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
