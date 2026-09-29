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
      hash = "sha256-vCuJArDZx5bILvRfFq4jB+F3V6/spe4VYjWj3HvaX4k=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-0cxJ36LNRD/DJiVES1n+YWtsgEeMyiEJhRGDRxdN11g=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-rCPiACSrPHHn9QBp+LNBkK7BstjwwswZg0A5s9rHM3M=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-/lR2GplQJm46eN22aor14GclEWnaMGoojgdR3mPYNv4=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported rtk platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "rtk";
    version = "0.50.0";

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
