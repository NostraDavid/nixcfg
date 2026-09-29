{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-IMWalOOGcyEZuoj7UcchLgKWSTFmjIEUwM1aWymuaXE=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-9vmgkJ+Nm2exvVXLKoErNb7gSSvTRtIm7m1poJ9jkr0=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-EaUpZVPgoZSOsJ3sixJKEbwygqn5DAdKzFrsqRCrPFI=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-RUPHrGKEMayx21nJDGnuBo8sFxinQk9VoiENduoHnL4=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported fixit platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "fixit";
    version = "1.0.0";

    src = fetchurl {
      url = "https://github.com/eugene-babichenko/fixit/releases/download/v${finalAttrs.version}/fixit-v${finalAttrs.version}-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      tar -xzf "$src" -C "$out/bin"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "A utility to fix mistakes in your commands";
      homepage = "https://github.com/eugene-babichenko/fixit";
      license = lib.licenses.mit;
      mainProgram = "fixit";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
