{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenvNoCC,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-xuoygfb/gmKDUbLQlnyeuFhiyKDsDrwk5j5kXIsCRi4=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-ObNKEka3IWAxqYroOMeFp9u6Kc+fUPEJEUrEYqS4Xnw=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-JVrHKHKf30McPdDSOsA8zm1RmYzIiog+yLx76TI7CwU=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-sptESZ0RlEu1zs3WC0nq8UgfTD/gMatFot8aNtrbhEU=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported beads platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "beads";
    version = "1.3.2";

    src = fetchurl {
      url = "https://github.com/gastownhall/beads/releases/download/v${finalAttrs.version}/beads_${finalAttrs.version}_${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];
    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted
      install -Dm755 extracted/bd "$out/bin/bd"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "Dependency-aware issue tracker for coding agents";
      homepage = "https://github.com/gastownhall/beads";
      changelog = "https://github.com/gastownhall/beads/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "bd";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
