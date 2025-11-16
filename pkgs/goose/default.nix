{
  lib,
  stdenvNoCC,
  fetchzip,
  autoPatchelfHook,
  libxcb,
  libX11,
  libXcursor,
  libXrandr,
  libXi,
  libGL,
  fontconfig,
  freetype,
  expat,
  gcc-unwrapped,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "goose";
  version = "1.14.0";

  src = fetchzip {
    url = "https://github.com/block/goose/releases/download/v${finalAttrs.version}/goose-x86_64-unknown-linux-gnu.tar.bz2";
    hash = "sha256-4VjLp9nQ/HFbb2WI4fu5HmE+TsFZqYGZhvXZk74RF/c=";
    stripRoot = false;
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    libxcb
    libX11
    libXcursor
    libXrandr
    libXi
    libGL
    fontconfig
    freetype
    expat
    gcc-unwrapped
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    install -Dm755 goose $out/bin/goose
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
