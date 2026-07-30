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
    version = "0.44.1";

    src = fetchFromGitHub {
      owner = "rtk-ai";
      repo = "rtk";
      rev = "v${version}";
      sha256 = "sha256-5AN/sK0IOIqcLX0FviFPOJ9QX9xJpliSN1XY3isxyrA=";
    };

    cargoHash = "sha256-Hd8dy0atCeTie2rZ3nfpbwbTHrIueNlXo7kpmK6QQNU=";

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
