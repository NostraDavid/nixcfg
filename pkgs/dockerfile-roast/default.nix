{
  fetchurl,
  lib,
  stdenvNoCC,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      name = "droast-linux-x86_64";
      hash = "sha256-ytuWOgQLouaGQa92T3lOXU+zNxu5uSJV+lAnBgsI6m4=";
    };
    aarch64-linux = {
      name = "droast-linux-arm64";
      hash = "sha256-CADoDRH2aGFfyHdQ9YgJtWvtyoPsbYpTnapW9C2mS8M=";
    };
    x86_64-darwin = {
      name = "droast-macos-x86_64";
      hash = "sha256-+B74umwvANI9cgDaTbIpSIttB0cjDEt/82Nrq1KU2ok=";
    };
    aarch64-darwin = {
      name = "droast-macos-arm64";
      hash = "sha256-Xk/Ld/0afq3Vbh30YMUemoQq5oq6pME7I/hx7paMgZU=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported dockerfile-roast platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "dockerfile-roast";
    version = "1.7.0";

    src = fetchurl {
      url = "https://github.com/immanuwell/dockerfile-roast/releases/download/${finalAttrs.version}/${asset.name}";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/droast"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "Opinionated Dockerfile linter";
      homepage = "https://github.com/immanuwell/dockerfile-roast";
      changelog = "https://github.com/immanuwell/dockerfile-roast/releases/tag/${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "droast";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
