{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-0PS+W+medaynxknBHUuPT6mch8yp5AAlzbXhxOOlm/c=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-KtwEeyS3pFyLBU56UYC3demGlw1/BVsXjodDBOIVhk0=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-iCykN9iWpBQh6ZpBsW4fA1D3dSoFmEXiXfzLsnJ8cng=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-MEUT0ddBKI1YXlggk4O9To9scH1Ud0phy8C9dI/G6QA=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported mdschema platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "mdschema";
    version = "0.15.6";

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
