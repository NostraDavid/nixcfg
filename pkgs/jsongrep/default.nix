{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  versionCheckHook,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-rhivVk5VPQkYx4P198xacdexyy5lMZKA+CUXVfeK6eY=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-M38oe81FFvyRw22I0ZfRNmPNpPUdMRraYYbyYb6Qr/Q=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-+9UxbpGAOK1I0Kd2k0D3yVzrc0kGp3JQlHONXYV79ew=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-MWBItr1jnlGCdaqr/xtUlsx+pNFMb/wEjCq3vaR7wM4=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported jsongrep platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "jsongrep";
    version = "0.10.0";

    src = fetchurl {
      url = "https://github.com/micahkepe/jsongrep/releases/download/v${finalAttrs.version}/jsongrep-${finalAttrs.version}-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = [installShellFiles];

    installPhase = ''
      runHook preInstall
      mkdir extracted
      tar -xzf "$src" -C extracted --strip-components=1
      install -Dm755 extracted/jg "$out/bin/jg"
      installShellCompletion --cmd jg \
        --bash extracted/completions/jg.bash \
        --fish extracted/completions/jg.fish \
        --zsh extracted/completions/jg.zsh
      installManPage extracted/man/*.1
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "JSONPath-inspired query language over JSON documents";
      homepage = "https://github.com/micahkepe/jsongrep";
      changelog = "https://github.com/micahkepe/jsongrep/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "jg";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
