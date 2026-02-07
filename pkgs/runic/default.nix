{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "runic";
  version = "unstable-2025-08-08";

  src = fetchFromGitHub {
    owner = "itsHanibee";
    repo = "runic";
    rev = "822ac6431ed9e54b76e9acfec43117e4aef5f582";
    hash = "sha256-921HpurudxdqMSu2WsdpKNE60aMIz+ac+u3/XzLKndQ=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    install -Dm644 runic $out/share/X11/xkb/symbols/runic
  '';

  meta = {
    description = "Custom Runic XKB symbols layout";
    homepage = "https://github.com/itsHanibee/runic";
    license = lib.licenses.unfreeRedistributable;
    platforms = lib.platforms.linux;
  };
})
