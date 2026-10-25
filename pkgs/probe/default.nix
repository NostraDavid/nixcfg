{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-39jZK6fwBnkHsGnAMPwgk+zN0g4lVFN6gksflQO4arQ=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-pf70FtEWMZ0p5vIY1GZ0lrjpyoKXX6n5nHpxdwCE6dw=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-ll6glAVdQ+EGOL8xabntATEQ64Ykx73b/7jo/HlKyyk=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-l9gfnuH6T2+P9UXAgU2WnHSuJLG95CEyyRFjEvrxdJQ=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported probe platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "probe";
    version = "0.6.0-rc343";

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
