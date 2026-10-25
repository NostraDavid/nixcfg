{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  clang,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bend";
  version = "2.0.39";

  src = fetchurl {
    url = "https://github.com/bendlang/bend/releases/download/v${finalAttrs.version}/bend-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-bPRi/Y9wsJSklQ67cJqcT/2PHRGJ2c7fH9Y81dBBx6s=";
  };

  nativeBuildInputs = [autoPatchelfHook makeWrapper];
  dontBuild = true;
  # Stripping removes the Bun executable's embedded compiler.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r bin bend2 guide "$out/"
    wrapProgram "$out/bin/bend" \
      --prefix PATH : ${lib.makeBinPath [clang]} \
      --set-default BEND_NO_TELEMETRY 1
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    "$out/bin/bend" version | grep -Fx 'bend ${finalAttrs.version}'
    "$out/bin/bend" guide > guide.txt
    test -s guide.txt
    cat > hello.bend <<'BEND'
    import Base
    def main() -> IO(Unit):
      IO.print("42")
    BEND
    "$out/bin/bend" hello.bend --check-only
    "$out/bin/bend" hello.bend -o hello
    ./hello | grep -Fx '42'
    runHook postInstallCheck
  '';

  meta = {
    description = "Parallel programming language with dependent types and proofs";
    homepage = "https://bend-lang.com/";
    license = lib.licenses.asl20;
    mainProgram = "bend";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
