{
  fetchurl,
  lib,
  stdenvNoCC,
  _7zz,
}:
stdenvNoCC.mkDerivation {
  pname = "mlx-harness";
  version = "0.5.6";
  src = fetchurl {
    url = "https://github.com/MLXapp/Harness/releases/download/v0.5.6/MLX-Harness-0.5.6-arm64.dmg";
    hash = "sha256-BYR9LDshKb+0rmRmlE1baVpqLaopgh5kUTqAjOGNhoM=";
  };
  nativeBuildInputs = [_7zz];
  unpackPhase = ''
    runHook preUnpack
    7zz x "$src" -y
    runHook postUnpack
  '';
  sourceRoot = ".";
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R "MLX Harness.app" "$out/Applications/"
    runHook postInstall
  '';
  meta = {
    description = "Run AI models locally on Apple Silicon";
    homepage = "https://harness.mlx.app/";
    license = lib.licenses.asl20;
    platforms = ["aarch64-darwin"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
