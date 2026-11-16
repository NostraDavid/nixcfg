{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-lg23mjLXd2ZcyYFBx6zBBgqqd4BlZ4/jXpgQB7ZzTO8=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-v5BNAC6F+XyvxMXtrr8EVWxDhNY4ZPG/Y/zQ5D38UlM=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-HDmhH3VojyKFpS0O5vWLkaZ0NkdPQp8zzqDb2FAifg4=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-0FziJhqjMrpKJUtPZXQesrAgg0wnVVvfMvcLMmVY1Rs=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported mdschema platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "mdschema";
    version = "0.16.0";

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
