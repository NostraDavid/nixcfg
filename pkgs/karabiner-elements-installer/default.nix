{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "karabiner-elements-installer";
  version = "16.3.0";
  src = fetchurl {
    url = "https://github.com/pqrs-org/Karabiner-Elements/releases/download/v${finalAttrs.version}/Karabiner-Elements-${finalAttrs.version}.dmg";
    hash = "sha256-GcznvtPUinIiQspoO9G65Aa2qH/tUgco0ckd7hdbdeQ=";
  };
  nativeBuildInputs = [undmg];
  sourceRoot = ".";
  dontBuild = true;
  # Keep the signed installer intact; its scripts register the DriverKit services.
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 Karabiner-Elements.pkg "$out/share/Karabiner-Elements.pkg"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    test -s "$out/share/Karabiner-Elements.pkg"
    cmp Karabiner-Elements.pkg "$out/share/Karabiner-Elements.pkg"
  '';
  passthru.updateScript = nix-update-script {};
  meta = {
    description = "Official signed Karabiner-Elements installer with its virtual keyboard driver";
    homepage = "https://karabiner-elements.pqrs.org/";
    license = lib.licenses.unlicense;
    platforms = lib.platforms.darwin;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
