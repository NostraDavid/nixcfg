{
  fetchurl,
  lib,
  makeWrapper,
  nodejs_24,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chrome-devtools-mcp";
  version = "1.12.0";
  src = fetchurl {
    url = "https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-${finalAttrs.version}.tgz";
    hash = "sha256-Sq3jFnw+eBx5fWEJ7WA6DKW4yzY6KJ4uqsqpsMXSo2A=";
  };
  nativeBuildInputs = [makeWrapper];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/chrome-devtools-mcp"
    cp -r build package.json LICENSE "$out/lib/chrome-devtools-mcp/"
    for program in chrome-devtools-mcp chrome-devtools; do
      makeWrapper ${nodejs_24}/bin/node "$out/bin/$program" \
        --add-flags "$out/lib/chrome-devtools-mcp/build/src/bin/$program.js" \
        --set CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS 1
    done
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/chrome-devtools-mcp" --version | grep -F '${finalAttrs.version}'
    "$out/bin/chrome-devtools-mcp" --help > /dev/null
    runHook postInstallCheck
  '';
  meta = {
    description = "Chrome DevTools MCP server for browser automation and debugging";
    homepage = "https://github.com/ChromeDevTools/chrome-devtools-mcp";
    license = lib.licenses.asl20;
    mainProgram = "chrome-devtools-mcp";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
