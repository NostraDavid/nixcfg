{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  versionCheckHook,
  installShellCompletions ? stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-ni0ppxO5RHiyQN7C8Q4RMkzQX6123EPnxjm9+KEzems=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-OKr23OYwmf0QmIlI0Du8bAR0JTrvaWH8vmD40VSzkQE=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported Codex platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "codex";
    version = "0.159.2";

    src = fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-package-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = lib.optionals installShellCompletions [installShellFiles];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      tar -xzf "$src" -C "$out"
      ${lib.optionalString installShellCompletions ''
        installShellCompletion --cmd codex \
          --bash <($out/bin/codex completion bash) \
          --fish <($out/bin/codex completion fish) \
          --zsh <($out/bin/codex completion zsh)
      ''}
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];
    preInstallCheck = ''
      test -x "$out/bin/codex-code-mode-host"
      test -f "$out/codex-package.json"
      test -x "$out/codex-path/rg"
      ${lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
        test -x "$out/codex-resources/bwrap"
      ''}
    '';

    meta = {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${finalAttrs.version}/CHANGELOG.md";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      maintainers = with lib.maintainers; [malo delafthi];
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
