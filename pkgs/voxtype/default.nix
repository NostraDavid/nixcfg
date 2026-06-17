{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  llvmPackages,
  cmake,
  git,
  mold,
  alsa-lib,
  libxkbcommon,
  udev,
}:
rustPlatform.buildRustPackage rec {
  pname = "voxtype";
  version = "0.7.5";

  src = fetchFromGitHub {
    owner = "peteonrails";
    repo = "voxtype";
    rev = "v${version}";
    hash = "sha256-zsOG1mBTXN4gdsTb1pUPKXATfhV5ZjgEsIUk07asaGo=";
  };

  cargoHash = "sha256-YK5xZWPo7KAeWZeuMxNxHA3k6RR/MT2MIfEPcgMND00=";

  nativeBuildInputs = [
    pkg-config
    llvmPackages.clang
    cmake
    git
    mold
  ];

  buildInputs = [
    alsa-lib
    libxkbcommon
    udev
  ];

  env = {
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    RUSTFLAGS = "-C link-arg=-fuse-ld=mold";
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
