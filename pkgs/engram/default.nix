{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "engram";
  version = "1.20.0";

  src = fetchurl {
    url = "https://github.com/Gentleman-Programming/engram/releases/download/v${finalAttrs.version}/engram_${finalAttrs.version}_linux_amd64.tar.gz";
    hash = "sha256-fcMAMxjjA77iaaR3IUTzzgHI7HAL/VJKrsdncKzTico=";
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 engram $out/bin/engram
    runHook postInstall
  '';

  meta = {
    description = "Persistent memory, MCP server, and TUI for AI coding agents";
    homepage = "https://github.com/syntax-syndicate/engram-agent-memory";
    changelog = "https://github.com/Gentleman-Programming/engram/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "engram";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
