{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: let
  srcBySystem = {
    "x86_64-linux" = {
      platform = "linux";
      arch = "amd64";
      hash = "sha256-GcETeJ6KZr8RqA3BjPdefnuiOREgBfTpzWnbBfEaxSY=";
    };
    "aarch64-linux" = {
      platform = "linux";
      arch = "arm64";
      hash = "sha256-sYgPZvKZqytWUoyQu/9QyoJj5zMYaKMdC2yntn90aeU=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      arch = "amd64";
      hash = "sha256-kvroed4kPzwS/IBdTxVPmjMQkel0U2xANbrmlvlnMP8=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      arch = "arm64";
      hash = "sha256-cFZhhtLh0BFg7w3DWu/B/7RtHdSmD/QaRSSK34uJe5c=";
    };
  };
  srcInfo = srcBySystem.${stdenvNoCC.hostPlatform.system}
    or (throw "acli: unsupported system ${stdenvNoCC.hostPlatform.system}");
in {
  pname = "acli";
  version = "1.3.40-stable";

  src = fetchurl {
    url = "https://acli.atlassian.com/${srcInfo.platform}/${finalAttrs.version}/acli_${finalAttrs.version}_${srcInfo.platform}_${srcInfo.arch}.tar.gz";
    inherit (srcInfo) hash;
  };

  sourceRoot = "acli_${finalAttrs.version}_${srcInfo.platform}_${srcInfo.arch}";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 acli "$out/bin/acli"
    runHook postInstall
  '';

  meta = {
    description = "Official Atlassian CLI for Jira Cloud";
    homepage = "https://developer.atlassian.com/cloud/acli/";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "acli";
    platforms = builtins.attrNames srcBySystem;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
