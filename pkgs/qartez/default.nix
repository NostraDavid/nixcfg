{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "qartez";
  version = "0.11.0";

  src = fetchurl {
    url = "https://github.com/kuberstar/qartez-mcp/releases/download/v${finalAttrs.version}/qartez-${finalAttrs.version}-x86_64-unknown-linux-gnu.tar.xz";
    hash = "sha256-EXsDRYYZLCshCEd804uU/e+ZGA/bkdRnjaZ0BLmjYZY=";
  };

  sourceRoot = "qartez-${finalAttrs.version}-x86_64-unknown-linux-gnu";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 qartez qartez-guard qartez-setup -t $out/bin
    runHook postInstall
  '';

  meta = {
    description = "Semantic code intelligence MCP server for coding agents";
    homepage = "https://github.com/kuberstar/qartez-mcp";
    changelog = "https://github.com/kuberstar/qartez-mcp/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.unfree;
    mainProgram = "qartez";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
