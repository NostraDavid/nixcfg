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
      hash = "sha256-+8jNX6FHbfoEXqkdJZFX05EOa4tG7r574tQ9m9zWlUE=";
    };
    "aarch64-linux" = {
      platform = "linux";
      arch = "arm64";
      hash = "sha256-j8dhddKx4R+bmoFxYMURFdAj/KxUigQewcxqTHOsF7o=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      arch = "amd64";
      hash = "sha256-OBhe80XoIKhRK9xpxvZUMwS2RHdMN2RGVphmWRyXz7I=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      arch = "arm64";
      hash = "sha256-LoWReMa1B5N04opIb54R04qULPtJRX9gq3bQQUZRiRI=";
    };
  };
  srcInfo = srcBySystem.${stdenvNoCC.hostPlatform.system}
    or (throw "acli: unsupported system ${stdenvNoCC.hostPlatform.system}");
in {
  pname = "acli";
  version = "1.3.41-stable";

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
