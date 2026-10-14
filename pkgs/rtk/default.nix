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
      hash = "sha256-W5GcO8y3mbZ6YYZtDmF0EKT83xc+JhREDlneL6IANDY=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-zWJ8QJGtkLXlrKg8pa9m7kuKqFN6c2Uz+pBUT0YfHCs=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-S3FrL0XWd95ByZ932acRma0GC5jsL3jvcSiFMSs6ZXg=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-Sq4vYM/EnJ6BuMjFcCCqDLgk2mCMeLTwz1wJiOGegk4=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported rtk platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "rtk";
    version = "1.0.1";

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
