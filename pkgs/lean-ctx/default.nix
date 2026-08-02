{
  fetchurl,
  lib,
  nix-update-script,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lean-ctx";
  version = "3.9.13";

  src = fetchurl {
    url = "https://github.com/yvgude/lean-ctx/releases/download/v${finalAttrs.version}/lean-ctx-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-YlSsq9t/DfxDKRYSX0RSAQVGizjbYCOWJE1DvC0URw8=";
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 lean-ctx $out/bin/lean-ctx
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Context engineering layer for AI coding agents";
    homepage = "https://github.com/yvgude/lean-ctx";
    changelog = "https://github.com/yvgude/lean-ctx/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "lean-ctx";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
