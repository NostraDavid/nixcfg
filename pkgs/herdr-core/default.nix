{
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
}: let
  assets = {
    x86_64-linux = {
      target = "linux-x86_64";
      hash = "sha256-MFTsOZLOgMVxXXIcqp3O+mBWch0V3BE/R1CvznY7pd8=";
    };
    aarch64-linux = {
      target = "linux-aarch64";
      hash = "sha256-mHV5hSRdRfjXPdheaLE5t/FnwoSIu4nt2YNMP1pc9M8=";
    };
    aarch64-darwin = {
      target = "macos-aarch64";
      hash = "sha256-kHmNqt76jRJrkO8Lzb6cfdqcbPvwEaJHBlq12jSPNQ4=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "herdr-core";
    version = "0.1.22";
    src = fetchurl {
      url = "https://releases.herdr.dev/core/${finalAttrs.version}/herdr-core-${asset.target}.tar.gz";
      inherit (asset) hash;
    };
    sourceRoot = ".";
    dontBuild = true;
    dontFixup = true;
    nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isDarwin [makeWrapper];
    installPhase = ''
      runHook preInstall
      install -Dm755 herdr-core "$out/bin/herdr-core"
      ${lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
        # GUI launches inherit launchd's low soft limit. Holders and PTYs inherit
        # this per-process limit, including re-execs of the wrapped real binary.
        wrapProgram "$out/bin/herdr-core" --run '
          export PATH="$HOME/.local/bin:$PATH"
          nofile=$(ulimit -Sn)
          if [ "$nofile" != unlimited ] && [ "$nofile" -lt 65536 ]; then
            ulimit -Sn 65536 || exit 1
          fi
        '
      ''}
      ln -s herdr-core "$out/bin/hc"
      runHook postInstall
    '';
    meta = {
      description = "Terminal and agent backend for Herdr";
      homepage = "https://github.com/herdrdev/herdr-core";
      license = lib.licenses.asl20;
      mainProgram = "herdr-core";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
