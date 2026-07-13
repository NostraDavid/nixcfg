{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  glib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "xdgctl";
  version = "1.1";

  src = fetchFromGitHub {
    owner = "mitjafelicijan";
    repo = "xdgctl";
    rev = "v${finalAttrs.version}";
    hash = "sha256-V12soGlHi1poh1sracskpFF61+3FrNbYCUgcCQ4UEPI=";
  };

  nativeBuildInputs = [pkg-config];

  buildInputs = [glib];

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
    "PREFIX=$(out)"
  ];

  postInstall = ''
    install -Dm644 README.md $out/share/doc/${finalAttrs.pname}/README.md
  '';

  meta = {
    description = "TUI for managing XDG default applications";
    homepage = "https://github.com/mitjafelicijan/xdgctl";
    changelog = "https://github.com/mitjafelicijan/xdgctl/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.bsd2;
    mainProgram = "xdgctl";
    platforms = lib.platforms.linux;
  };
})
