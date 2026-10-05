{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenvNoCC,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-UCjTsZqPCZDTD+yfuwfjJ4K8VpjmGPsYYarYqcy6TrU=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-jW0arZ5ptCSB7acDlQfR9+6TaY+HcTzs2HPSh8GTFjI=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-vTnIFT9BRzWDYMfcUWZagTHMnuFvgfaalAL/pQC+PMI=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-iBfYtxr8AqyL8G6yS8xBwwZZKrc1to6P7p2xug3ny1k=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported rtk platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "rtk";
    version = "0.51.0";

    src = fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${finalAttrs.version}/rtk-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = lib.optionals (stdenvNoCC.hostPlatform.system == "aarch64-linux") [autoPatchelfHook];
    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted
      install -Dm755 extracted/rtk "$out/bin/rtk"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "CLI proxy that reduces LLM token consumption";
      homepage = "https://github.com/rtk-ai/rtk";
      changelog = "https://github.com/rtk-ai/rtk/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.asl20;
      mainProgram = "rtk";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
