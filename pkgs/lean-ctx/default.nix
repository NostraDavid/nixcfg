{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lean-ctx";
  version = "3.9.12";

  src = fetchurl {
    url = "https://github.com/yvgude/lean-ctx/releases/download/v${finalAttrs.version}/lean-ctx-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-TxnR8rlSKulinUDXNDP/OLcXUNFKsCMMJqHBpdMJwBQ=";
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 lean-ctx $out/bin/lean-ctx
    runHook postInstall
  '';

  meta = {
    description = "Local-first context optimization layer and MCP server";
    homepage = "https://github.com/yvgude/lean-ctx";
    changelog = "https://github.com/yvgude/lean-ctx/releases/tag/v${finalAttrs.version}";
    license = [
      lib.licenses.asl20
      lib.licenses.mit
    ];
    mainProgram = "lean-ctx";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
