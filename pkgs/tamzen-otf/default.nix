{
  stdenvNoCC,
  lib,
  fetchFromGitHub,
  nix-update-script,
  bdf2sfd,
  fontforge,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tamzen-otf";
  version = "1.11.6";
  src = fetchFromGitHub {
    owner = "sunaku";
    repo = "tamzen-font";
    tag = "Tamzen-${finalAttrs.version}";
    hash = "sha256-W5Wqsm5rpzzcbJl2lv6ORAznaAwLcmJ2S6Qo2zIoq9I=";
  };
  nativeBuildInputs = [bdf2sfd fontforge];
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/fonts/opentype"
    fontforge -lang py -script ${./convert.py}
    runHook postInstall
  '';
  passthru.updateScript = nix-update-script {
    extraArgs = ["--version-regex" "^Tamzen-(\\d+\\.\\d+\\.\\d+)$"];
  };
  meta = {
    description = "Tamzen bitmap programming font converted to OpenType";
    homepage = "https://github.com/sunaku/tamzen-font";
    license = lib.licenses.free;
    platforms = lib.platforms.all;
  };
})
