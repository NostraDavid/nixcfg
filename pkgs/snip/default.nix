{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-WWWb6kRflb5zswhMJJZTyXMUi6wwZ0hhqjXYRGv5K/U=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-JV6xqc33ZPIRpYplPpPZzldEoB3ik8qboltSVawUmPk=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-D44N7ysK1gC8MMMqc3E9tSYejvNTnObKqlNuDPQTzSQ=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-VGuQbAp81zjy5MTtemuZG06U3y9fzMEEIH4Cr3BC3w8=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported snip platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "snip";
    version = "0.26.0";

    src = fetchurl {
      url = "https://github.com/edouard-claude/snip/releases/download/v${finalAttrs.version}/snip_${finalAttrs.version}_${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted
      install -Dm755 extracted/snip "$out/bin/snip"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "CLI proxy that reduces LLM token usage";
      homepage = "https://github.com/edouard-claude/snip";
      changelog = "https://github.com/edouard-claude/snip/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "snip";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
