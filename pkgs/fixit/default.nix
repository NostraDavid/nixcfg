{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
}:
rustPlatform.buildRustPackage rec {
  pname = "fixit";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "eugene-babichenko";
    repo = "fixit";
    rev = "v${version}";
    # Fill this with the real hash after the first build attempt.
    sha256 = "sha256-Vl1nO9VcQF40m0MZ19SoxeC8mK24qzewamuFSiUyUWE=";
  };

  cargoHash = "sha256-VIvC65tJh0UUyr94wfDUg3En8SHBay+oMkkbK1QtiYI=";

  # Tests rely on integration with terminal emulators/multiplexers.
  doCheck = false;

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake"];
  };

  meta = with lib; {
    description = "A utility to fix mistakes in your commands (fast CLI, inspired by The Fuck).";
    homepage = "https://github.com/eugene-babichenko/fixit";
    license = licenses.mit;
    mainProgram = "fixit";
    maintainers = [];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
