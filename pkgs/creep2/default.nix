{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "creep2";
  version = "0-unstable-69dc0de";

  src = fetchFromGitHub {
    owner = "raymond-w-ko";
    repo = "creep2";
    rev = "69dc0de03d89f31b8074981cec0be45d4aceb245";
    sha256 = "0p0rlvdf6ih5z0s1x2xrgn9kq37m2zhn3slla752zfm0gaz6jnl9";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 creep2.ttf "$out/share/fonts/truetype/creep2.ttf"
    install -Dm644 creep2-11.bdf "$out/share/fonts/misc/creep2-11.bdf"
    install -Dm644 LICENSE "$out/share/licenses/creep2/LICENSE"
    runHook postInstall
  '';

  meta = {
    description = "Small pixel font with a strict 5x11 character bounding box";
    homepage = "https://github.com/raymond-w-ko/creep2";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
