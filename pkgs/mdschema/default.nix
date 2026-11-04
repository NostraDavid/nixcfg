{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-aV1SBqpmlj5buf+23Vkc/uG5WJKuhy2bkXJpe5PkVUo=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-5ZOlymj5Dmm7eHM9ZG+kvoKyol4XeeV2GxRUjHab/3I=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-4HcJvCdPqkG7EHAsqKGhME05h1t86zWErESiarIfejw=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-myzcwGJsY8zmYplyQCeZ+CtvdxVnS0uZ1t28MSVyUhQ=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported mdschema platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "mdschema";
    version = "0.15.7";

    src = fetchurl {
      url = "https://github.com/jackchuka/mdschema/releases/download/v${finalAttrs.version}/mdschema_${finalAttrs.version}_${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      tar -xzf "$src" -C "$out/bin" mdschema
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];
    versionCheckProgramArg = "version";

    meta = {
      description = "Declarative schema-based Markdown documentation validator";
      homepage = "https://github.com/jackchuka/mdschema";
      changelog = "https://github.com/jackchuka/mdschema/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "mdschema";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
