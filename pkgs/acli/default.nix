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
      hash = "sha256-zeKlmUZlV2sGXQVAWqC4mriyi0mBIlPwpNPf4HqWzIw=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      arch = "amd64";
      hash = "sha256-skOufBhNGkz/3D+qVjOvesiWPTG/Wk7p0GudTWh/7QQ=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      arch = "arm64";
      hash = "sha256-QRJdta2SiSWezeR31mIxgQhqzQgz1BQsUu38F/ks4wk=";
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
