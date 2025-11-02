{
  lib,
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "goose";
  version = "1.12.1";

  src = fetchzip {
    url = "https://github.com/block/goose/releases/download/v${finalAttrs.version}/goose-x86_64-unknown-linux-gnu.tar.bz2";
    hash = "sha256-eHtjtntDMHEgzZMdpu4OI0E+i2jjtPAnAH9korjUQoA=";
    stripRoot = false;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    install -Dm755 goose $out/bin/goose
    install -Dm755 temporal $out/bin/temporal
    install -Dm755 temporal-service $out/bin/temporal-service
  '';

  passthru.updateScript = ../../cmd/update-goose.sh;

  meta = {
    description = "Open source, extensible AI agent that executes, edits, and tests with any LLM";
    homepage = "https://block.github.io/goose/";
    changelog = "https://github.com/block/goose/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "goose";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [lib.sourceTypes.binaryNativeCode];
  };
})
