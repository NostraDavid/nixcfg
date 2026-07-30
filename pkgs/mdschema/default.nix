{
  lib,
  fetchFromGitHub,
  nix-update-script,
  buildGoModule,
}:
buildGoModule rec {
  pname = "mdschema";
  version = "0.14.1";

  src = fetchFromGitHub {
    owner = "jackchuka";
    repo = "mdschema";
    rev = "v${version}";
    hash = "sha256-aJ53lHYrgESJqchcCCuN3XsVW8sfFDPtv5K4KF4mGGE=";
  };

  vendorHash = "sha256-g7pQsR4+xxEn5w7o1YvxiS8kuEIP1+krpUkGWjI7Pfg=";

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
