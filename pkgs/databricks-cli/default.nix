{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation (finalAttrs: let
  srcBySystem = {
    "x86_64-linux" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_linux_amd64.tar.gz";
      hash = "sha256-UiSIhClyoGk2IHpQNCatNk2AYdouMwY22mD0RKMoQPU=";
    };
    "aarch64-linux" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_linux_arm64.tar.gz";
      hash = "sha256-4ckkqVgZ18eS9xpBwhbSqtlVAMrtqbhY3uZ2gwd6WgY=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_darwin_amd64.tar.gz";
      hash = "sha256-Kx08ZJ04Q0znW/9eIhLfA6dBtXmRV5IRHg8EqDP59vI=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_darwin_arm64.tar.gz";
      hash = "sha256-ZsnL42/Aq7SR4HRhJKlepkQFQRLmte14rbDuUwxN2vA=";
    };
  };

  srcInfo = srcBySystem.${stdenv.hostPlatform.system}
    or (throw "databricks-cli: unsupported system ${stdenv.hostPlatform.system}");
in {
  pname = "databricks-cli";
  version = "1.26.0";

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
