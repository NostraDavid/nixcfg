{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_x86_64";
      hash = "sha256-EStGuO4z9i+afjHAu61dph/0xD3gVjvw/A2AL5/1I84=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-T8weXg4imAijvGe403CtIZQBnhp7lF8zFtX1QgOkUE8=";
    };
    x86_64-darwin = {
      target = "darwin_x86_64";
      hash = "sha256-dLvx0I4i6VYDkOMyHdtETjLCsMhotpt49LKGBY2dYb8=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-XyKY+ILZklVaN+gnkDsfZ5ibqemQ86nAsVT23dtNmuc=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported bitbucket-cli platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bitbucket-cli";
    version = "0.34.0";

    src = fetchurl {
      url = "https://github.com/avivsinai/bitbucket-cli/releases/download/v${finalAttrs.version}/bkt_${finalAttrs.version}_${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted
      install -Dm755 extracted/bkt "$out/bin/bkt"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "Bitbucket CLI for Bitbucket Cloud and Data Center";
      homepage = "https://github.com/avivsinai/bitbucket-cli";
      changelog = "https://github.com/avivsinai/bitbucket-cli/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "bkt";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
