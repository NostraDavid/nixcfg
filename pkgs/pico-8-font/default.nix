{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "pico-8-font";
  version = "1.0";

  # Replacement download posted in the upstream thread on 2024-01-06.
  # The original RhythmLynx downloads are unavailable; this is Simbax's update.
  src = fetchurl {
    name = "pico-8.ttf";
    url = "https://drive.usercontent.google.com/download?id=1orWXqd0x6Hf-MWf_RNRYgSRZ2Zr-E_Gv&export=download";
    sha256 = "0fvdna10gzr634zi4dzzkfq3yp42mkcvyv813rbpy0rcav6vpmp8";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 "$src" "$out/share/fonts/truetype/pico-8.ttf"
    runHook postInstall
  '';

  meta = {
    description = "PICO-8 pixel font with updated Unicode mappings by Simbax";
    homepage = "https://www.lexaloffle.com/bbs/?tid=3760";
    # Declared in the TTF's embedded license metadata.
    license = lib.licenses.cc0;
    platforms = lib.platforms.all;
  };
}
