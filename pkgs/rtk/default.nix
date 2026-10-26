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
      hash = "sha256-lFStG5SJ2qV6sKn06+L6r03IK4oPJsnlE1FRq9fJN40=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-pcAMOrASmIS8t1fTSK/BplDvoPTwdp2pfDQfKPiXGe0=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-HiPouVQrWEKOZAnEmxw/uSxMDVEl2nLoDwAqRghqbCA=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-jadzsJVM+QsRXslcTk60IPBMOd4jPF2xAiRqbK8HO6c=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported rtk platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "rtk";
    version = "1.1.0";

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
