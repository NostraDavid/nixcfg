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
      hash = "sha256-kaDlhQlY4+rYqhEQFV94WWtaA6adYKXckd4hC/FzQOU=";
    };
    "aarch64-linux" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_linux_arm64.tar.gz";
      hash = "sha256-J5ABkFdVlkGBQumhMOe1azp7/aHT39Hz87agyj7HGEY=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_darwin_amd64.tar.gz";
      hash = "sha256-DaB2GE23VOMEAVH1Tt7VqwTzZ8FKLpjsmFosCL/y5go=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_darwin_arm64.tar.gz";
      hash = "sha256-3PT06qTV8P5Mr4CN+2rEs6K6B0Ali45qVrHnL9I+8fk=";
    };
  };

  srcInfo = srcBySystem.${stdenv.hostPlatform.system}
    or (throw "databricks-cli: unsupported system ${stdenv.hostPlatform.system}");
in {
  pname = "databricks-cli";
  version = "1.22.1";

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
