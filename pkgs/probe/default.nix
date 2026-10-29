{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-TpbZ0mDzGog9I2YutxorZRuObUNkGXpy13BbIeV0HtY=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-x3ieihTw3qMp+7lZbFgE/fC2nPtKpFmOcWt/dlDghBw=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-3xogdPVIa1zFYtQMV5QdmtXBwA65GIVeHRFojA/5QMc=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-F5dufXej/NjkteNeD/8ADQC9iYdVI8imS1FnTEJn4OA=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported probe platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "probe";
    version = "0.6.0-rc344";

    src = fetchurl {
      url = "https://github.com/probelabs/probe/releases/download/v${finalAttrs.version}/probe-v${finalAttrs.version}-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted --strip-components=1
      install -Dm755 extracted/probe "$out/bin/probe"
      runHook postInstall
    '';

    doInstallCheck = true;
    # Release candidates report only the base version in the binary.
    installCheckPhase = ''
      runHook preInstallCheck
      test "$($out/bin/probe --version)" = "probe-code ${builtins.head (lib.splitString "-" finalAttrs.version)}"
      runHook postInstallCheck
    '';

    meta = {
      description = "AST-aware code search and context engine";
      homepage = "https://github.com/probelabs/probe";
      changelog = "https://github.com/probelabs/probe/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.asl20;
      mainProgram = "probe";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
