{
  lib,
  fetchFromGitHub,

  buildGoModule,
}:
buildGoModule rec {
  pname = "mdschema";
  version = "0.13.2";

  src = fetchFromGitHub {
    owner = "jackchuka";
    repo = "mdschema";
    rev = "v${version}";
    hash = "sha256-phJW81xrsJ53KZa7ij9FAjNJNRcC85qBFdTeWr0F6Hg=";
  };

  vendorHash = "sha256-gDhf7olHFYRrjh6VYIs6bnH3p8QxMNDQsppRfuitNsQ=";

  subPackages = ["cmd/mdschema"];

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake"];
  };

  meta = with lib; {
    description = "Declarative schema-based Markdown documentation validator";
    homepage = "https://github.com/jackchuka/mdschema";
    changelog = "https://github.com/jackchuka/mdschema/releases/tag/v${version}";
    license = licenses.mit;
    mainProgram = "mdschema";
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [];
  };
}
