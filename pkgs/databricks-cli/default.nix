{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation (finalAttrs: let
  srcBySystem = {
    "x86_64-linux" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_linux_amd64.tar.gz";
      hash = "sha256-pewIj39sxZdDJ6Qt+ZJh4i+8b3ypzduUUzPCON2eIok=";
    };
    "aarch64-linux" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_linux_arm64.tar.gz";
      hash = "sha256-DIMludcfVHzt8VofSQVAYjga3G1ggO1ViQU6fFL+x2w=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_darwin_amd64.tar.gz";
      hash = "sha256-KmAqBAFnX/5m2peILcEs5lGrQe47QjVn74BpBPWSd20=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/databricks/cli/releases/download/v${finalAttrs.version}/databricks_cli_${finalAttrs.version}_darwin_arm64.tar.gz";
      hash = "sha256-dQ5Mxp3x5fctIjPzOLm+4YT6dQWJDdordzm3vRNKCSo=";
    };
  };

  srcInfo = srcBySystem.${stdenv.hostPlatform.system}
    or (throw "databricks-cli: unsupported system ${stdenv.hostPlatform.system}");
in {
  pname = "databricks-cli";
  version = "1.23.0";

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
