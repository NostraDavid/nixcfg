{
  fetchurl,
  lib,
  nix-update-script,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "engram";
  version = "2.0.0";

  src = fetchurl {
    url = "https://github.com/Gentleman-Programming/engram/releases/download/v${finalAttrs.version}/engram_${finalAttrs.version}_linux_amd64.tar.gz";
    hash = "sha256-I74cLOlznEVQl/+GRzYhNxe5JbPoghqYjfxhloWlq9U=";
  };

  sourceRoot = ".";
  dontBuild = true;

  passthru.updateScript = nix-update-script {
    extraArgs = ["--use-github-releases" "--version-regex" "^v(\\d+\\.\\d+\\.\\d+)$"];
  };

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
