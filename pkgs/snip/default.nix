{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "linux_amd64";
      hash = "sha256-91Jy2eVf9um+318YoTRQkH9i90eotD0DynA7gjV0GOg=";
    };
    aarch64-linux = {
      target = "linux_arm64";
      hash = "sha256-lpGUMAvfRzccaPMGKbhpLyRRw5t3pqgj3G/IjnNudEk=";
    };
    x86_64-darwin = {
      target = "darwin_amd64";
      hash = "sha256-fi3bHDV48MGF9VRBFGkLDCY5GUjVftrvmLh9FfR5ugw=";
    };
    aarch64-darwin = {
      target = "darwin_arm64";
      hash = "sha256-pJW4uRzB1Rz/0LRJDlNrls0Cb1CAs54XNqKVgOwzVGU=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported snip platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "snip";
    version = "0.25.2";

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
