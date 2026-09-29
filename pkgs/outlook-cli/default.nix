{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-TSaaaJg5lDeMtc6YmwlNO/djQm0nF4dS18bTH5bxc3Q=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-S8sHaFQzXvUgJ2zvOoJIIQFstDnu2lycJluz+cp1kgM=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-gw7l7tGjICrGqibPTMPbybYDyBRt3WT+wDgjPnjKeCk=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-blveihZ6xmg6HggPFBtTetmquk3MzU9GvSB2z5Bv7m8=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported outlook-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "outlook-cli";
    version = "0.2.5";

    src = fetchurl {
      url = "https://github.com/rvben/outlook-cli/releases/download/v${finalAttrs.version}/outlook-v${finalAttrs.version}-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted
      install -Dm755 extracted/outlook "$out/bin/outlook"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "Microsoft Outlook mail and calendar CLI";
      homepage = "https://github.com/rvben/outlook-cli";
      changelog = "https://github.com/rvben/outlook-cli/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "outlook";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
