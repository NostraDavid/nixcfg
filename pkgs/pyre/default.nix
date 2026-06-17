{
  lib,
  rustPlatform,
  fetchFromGitHub,
  mold,
}:
rustPlatform.buildRustPackage {
  pname = "pyre";
  version = "unstable-2026-04-01";

  src = fetchFromGitHub {
    owner = "youknowone";
    repo = "pyre";
    rev = "37c7e45c58e23b727628fe56b9aecc240768bc2c";
    hash = "sha256-QjUfzwUBCgApS5gqTAWVg4ZfWQdBm1Z69VHO3HOeSwQ=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  cargoBuildFlags = [
    "-p"
    "pyrex"
  ];

  cargoInstallFlags = [
    "-p"
    "pyrex"
  ];

  prePatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  nativeBuildInputs = [
    mold
  ];

  env.RUSTFLAGS = "-C link-arg=-fuse-ld=mold";

  doCheck = false;

  meta = {
    description = "No-GIL Python implementation in Rust with a meta-tracing JIT";
    homepage = "https://github.com/youknowone/pyre";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "pyre";
    platforms = lib.platforms.linux;
  };
}
