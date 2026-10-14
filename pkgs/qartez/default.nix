{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
  versionCheckHook,
  zlib,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-EXsDRYYZLCshCEd804uU/e+ZGA/bkdRnjaZ0BLmjYZY=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-iMoPyl7MRjoYk3FnWCqMdkEAwQRWQzmokDJuveF0c54=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "qartez";
    version = "0.11.0";

    src = fetchurl {
      url = "https://github.com/kuberstar/qartez-mcp/releases/download/v${finalAttrs.version}/qartez-${finalAttrs.version}-${asset.target}.tar.xz";
      inherit (asset) hash;
    };

    sourceRoot = "qartez-${finalAttrs.version}-${asset.target}";
    nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [stdenv.cc.cc.lib zlib];
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 qartez qartez-guard qartez-setup -t $out/bin
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "Semantic code intelligence MCP server for coding agents";
      homepage = "https://github.com/kuberstar/qartez-mcp";
      changelog = "https://github.com/kuberstar/qartez-mcp/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.unfree;
      mainProgram = "qartez";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
