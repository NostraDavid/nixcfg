{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.42.4";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "v${version}";
    sha256 = "sha256-8nLJ5PVefXmoXQyw6HERfCP06C+l4I+7XLwKFNVNpew=";
  };

  cargoHash = "sha256-YsKOyEZ281ojqiitnvCFGy/MzHMyr4hlxqMnvrQwguQ=";

  doCheck = false;

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake"];
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
