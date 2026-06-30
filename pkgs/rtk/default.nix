{
  lib,
  stdenv,
  stdenvAdapters,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
}: let
  effectiveStdenv =
    if stdenv.hostPlatform.isLinux
    then stdenvAdapters.useMoldLinker stdenv
    else stdenv;
in
  (rustPlatform.buildRustPackage.override {stdenv = effectiveStdenv;}) rec {
    pname = "rtk";
    version = "0.43.0";

    src = fetchFromGitHub {
      owner = "rtk-ai";
      repo = "rtk";
      rev = "v${version}";
      sha256 = "sha256-n5bkPPsrdM4fE5ltocTjlq+JwRgp39yib6S79fci4m4=";
    };

    cargoHash = "sha256-XKUKdhxfnwUCOx9slqx4oUFa09HcosPLVh5Xkh87oSk=";

    doCheck = false;

    passthru.updateScript = nix-update-script {
      extraArgs = [
        "--flake"
        "--url=https://github.com/rtk-ai/rtk"
        "--use-github-releases"
        "--version-regex=^v(\\d+\\.\\d+\\.\\d+)$"
      ];
    };

    meta = with lib; {
      description = "High-performance CLI proxy that reduces LLM token consumption";
      homepage = "https://github.com/rtk-ai/rtk";
      license = licenses.asl20;
      mainProgram = "rtk";
      maintainers = [];
      platforms = platforms.linux ++ platforms.darwin;
    };
  }
