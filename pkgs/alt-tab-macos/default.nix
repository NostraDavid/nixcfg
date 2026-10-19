{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "alt-tab-macos";
  version = "11.9.2";
  src = fetchurl {
    url = "https://github.com/lwouis/alt-tab-macos/releases/download/v${finalAttrs.version}/AltTab-${finalAttrs.version}.zip";
    hash = "sha256-qApH/uaLHVgoKj8gTID+JoIlLtFpxdc6Cidv0K35DHU=";
  };
  nativeBuildInputs = [unzip];
  dontUnpack = true;
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    unzip -q "$src" -d "$out/Applications"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    test -x "$out/Applications/AltTab.app/Contents/MacOS/AltTab"
    test -s "$out/Applications/AltTab.app/Contents/_CodeSignature/CodeResources"
  '';
  passthru.updateScript = nix-update-script {};
  meta = {
    description = "Windows-style window switching for macOS";
    homepage = "https://alt-tab.app/";
    license = [lib.licenses.gpl3Plus lib.licenses.cc-by-40];
    platforms = lib.platforms.darwin;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
