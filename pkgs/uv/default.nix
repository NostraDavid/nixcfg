{
  fetchurl,
  installShellFiles,
  lib,
  stdenvNoCC,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-WMz18XkrilqI0BvJEOoTGos9tKMZoXrV+tdeCEWj4nE=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-N/u3xbxmz5nBKqiBlJ0hYYHiAd7ESXcsQynlZIfWEXk=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-WuymfyKD91I13kDQvZwKW7xfziO21Is7+fobLbCDgso=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-YXoyESYbD8c5Vi8Acao06XOXl8UQII7ejil3wwkD0EE=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
  canExecute = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "uv";
    version = "0.13.9";

    src = fetchurl {
      url = "https://github.com/astral-sh/uv/releases/download/${finalAttrs.version}/uv-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontBuild = true;
    nativeBuildInputs = [installShellFiles];
    installPhase = ''
      runHook preInstall
      install -Dm755 uv uvx -t "$out/bin"
      ${lib.optionalString canExecute ''
        installShellCompletion --cmd uv \
          --bash <("$out/bin/uv" generate-shell-completion bash) \
          --fish <("$out/bin/uv" generate-shell-completion fish) \
          --zsh <("$out/bin/uv" generate-shell-completion zsh)
      ''}
      runHook postInstall
    '';

    doInstallCheck = canExecute;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/uv" --version | grep -F 'uv ${finalAttrs.version}'
      "$out/bin/uvx" --version | grep -F 'uvx ${finalAttrs.version}'
      runHook postInstallCheck
    '';

    meta = {
      description = "Extremely fast Python package and project manager, written in Rust";
      homepage = "https://github.com/astral-sh/uv";
      changelog = "https://github.com/astral-sh/uv/releases/tag/${finalAttrs.version}";
      license = with lib.licenses; [asl20 mit];
      mainProgram = "uv";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
