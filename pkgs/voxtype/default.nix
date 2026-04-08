{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  llvmPackages,
  cmake,
  git,
  alsa-lib,
  libxkbcommon,
  udev,
}:

rustPlatform.buildRustPackage rec {
  pname = "voxtype";
  version = "0.6.5";

  src = fetchFromGitHub {
    owner = "peteonrails";
    repo = "voxtype";
    rev = "v${version}";
    hash = "sha256-gY5gP+F3SbCZsG/jaOHnEu291q6akg1M5c4BebRSpvI=";
  };

  cargoHash = "sha256-X6TYlmHjLvsUYlxz4WbzHptKyQZHIBt8u1lLqrS/nz0=";

  nativeBuildInputs = [
    pkg-config
    llvmPackages.clang
    cmake
    git
  ];

  buildInputs = [
    alsa-lib
    libxkbcommon
    udev
  ];

  env = {
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  };

  postInstall = ''
    install -Dm644 README.md $out/share/doc/${pname}/README.md
  '';

  meta = {
    description = "Push-to-talk voice-to-text for Wayland compositors";
    homepage = "https://github.com/peteonrails/voxtype";
    changelog = "https://github.com/peteonrails/voxtype/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "voxtype";
    platforms = lib.platforms.linux;
  };
}
