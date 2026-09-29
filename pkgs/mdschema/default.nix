{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-KfMsmP3c3p3FOB5W3wSQ9eRUNt9yYK64r6AWHqtj+4E=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-/ptnJ4jqsh0Sh40h9odTvrqtNSNXcjzWGH3BkwnRqTo=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-a445foYya3QIykkDuTWXC+R2eDhSv6nPBPxG/PYCVIQ=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-cr4w8eknUvwtQAa39ZL+Pe5TNhV3Yg3mzDGSaBUu+ak=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported mdschema platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "mdschema";
    version = "0.15.4";

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
