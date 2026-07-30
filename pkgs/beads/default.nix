{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "beads";
  version = "1.1.2";

  src = fetchurl {
    url = "https://github.com/gastownhall/beads/releases/download/v${finalAttrs.version}/beads_${finalAttrs.version}_linux_amd64.tar.gz";
    hash = "sha256-py1x7TdJVdyfg6D5C1S9e2oAFnCd0Wdq4uNoZR7UAcI=";
  };
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 bd $out/bin/bd
    ln -s bd $out/bin/beads

    runHook postInstall
  '';

  meta = {
    description = "Distributed graph issue tracker for AI agents";
    homepage = "https://github.com/gastownhall/beads";
    changelog = "https://github.com/gastownhall/beads/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "bd";
    platforms = ["x86_64-linux"];
  };
})
