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
      hash = "sha256-fg+02+2xu5EA+NyFTTHUPEt8LHQOTP2Dt1B2D0lXtaU=";
    };
    "aarch64-linux" = {
      platform = "linux";
      arch = "arm64";
      hash = "sha256-r7OGW03fJ+So6J6uWYSWMuS+wXVDRLENdO70MyRW+lo=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      arch = "amd64";
      hash = "sha256-bML5SErq5//yd2V+yLT4gobVaWtzfgMJIkOy+8HbasI=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      arch = "arm64";
      hash = "sha256-KRJr24BysSZwny08yqxYHNf5G2KvqpBGrpwdQ7LluTk=";
    };
  };
  srcInfo = srcBySystem.${stdenvNoCC.hostPlatform.system}
    or (throw "acli: unsupported system ${stdenvNoCC.hostPlatform.system}");
in {
  pname = "acli";
  version = "1.3.39-stable";

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
