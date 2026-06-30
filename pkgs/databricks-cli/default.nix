{
  lib,
  stdenv,
  fetchurl,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: let
  srcBySystem = {
    "x86_64-linux" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_linux_amd64.tar.gz";
      hash = "sha256-GqXvHjJgdeFbeCBDe+EmEgnFlh0uUgsc4qpR6CrvH24=";
    };
    "aarch64-linux" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_linux_arm64.tar.gz";
      hash = "sha256-37lWXOHuKcDlXcKFYcKxrP+tDHOzaLyiQ3VUdul8lqo=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_darwin_amd64.tar.gz";
      hash = "sha256-D2ToSWt9te4PLm9Fhzvu5lHw90JHj257D/6w4X2StLc=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_darwin_arm64.tar.gz";
      hash = "sha256-dLvUKZwBtKLLsUppuW69zUUrDukRhaF9w8v6cfxKinw=";
    };
  };

  srcInfo = srcBySystem.${stdenv.hostPlatform.system}
    or (throw "databricks-cli: unsupported system ${stdenv.hostPlatform.system}");
in {
  pname = "databricks-cli";
  version = "1.5.0";

  src = fetchurl {
    inherit (srcInfo) url hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    tar -xzf $src
    install -m 0755 databricks $out/bin/databricks
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake"];
  };

  meta = with lib; {
    description = "Databricks CLI";
    homepage = "https://github.com/databricks/cli";
    changelog = "https://github.com/databricks/cli/releases/tag/v${finalAttrs.version}";
    license = licenses.unfreeRedistributable;
    mainProgram = "databricks";
    platforms = builtins.attrNames srcBySystem;
    maintainers = [];
  };
})
