{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  autoreconfHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "austin";
  version = "4.0.0";

  src = fetchFromGitHub {
    owner = "P403n1x87";
    repo = "austin";
    rev = "v${finalAttrs.version}";
    hash = "sha256-FvYDlBYTdsUs42lsYQ5OUjzhvB5MCBFN6qsHToL4okA=";
  };

  nativeBuildInputs = [
    autoreconfHook
  ];

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Frame stack sampler for CPython";
    homepage = "https://github.com/P403n1x87/austin";
    changelog = "https://github.com/P403n1x87/austin/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "austin";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
