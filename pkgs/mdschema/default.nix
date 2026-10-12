{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-+CpseYIONs1SRlvM+uvtqUsqgBRnXMcFTYMbelfqIE8=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-7gRpuQPzrkT5T7S8LXsEnEUmd2M4UNyDgIvGylTd9ss=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-PvjVhGa9QD2n+Db7H+Tz8f+m3hyeBMV4OPAPoFpa9NE=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-gflG9ecUy42HI2JpALuihQ7AcHxViG0OSSp8hYeWFg0=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported mdschema platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "mdschema";
    version = "0.15.5";

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
