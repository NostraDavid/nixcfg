{
  lib,
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.0.67";

  src = fetchzip {
    url = "https://github.com/sst/opencode/releases/download/v${finalAttrs.version}/opencode-linux-x64.zip";
    # nix store prefetch-file https://github.com/sst/opencode/releases/download/v1.0.67/opencode-linux-x64.zip
    hash = "sha256-TPEaMA3bN5Qwjg03q6WlFmej6VVI+ZgcAIVDipZGWCQ=";
    stripRoot = false;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    install -Dm755 opencode $out/bin/opencode
  '';

  passthru.updateScript = ../../cmd/update-opencode.sh;

  meta = {
    description = "The AI coding agent built for the terminal";
    homepage = "https://opencode.ai";
    changelog = "https://github.com/sst/opencode/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "opencode";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [lib.sourceTypes.binaryNativeCode];
  };
})
