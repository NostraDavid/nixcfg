{
  lib,
  fetchFromGitHub,
  nix-update-script,
  buildGoModule,
}:
buildGoModule rec {
  pname = "mdschema";
  version = "0.15.4";

  src = fetchFromGitHub {
    owner = "jackchuka";
    repo = "mdschema";
    rev = "v${version}";
    hash = "sha256-zsSiK/6/2EzI/yPi0MacucM/cg3z+s+n14Fsv195yxw=";
  };

  vendorHash = "sha256-m2nwsdYab7w+aT7a4eXXKjnTRCaddm5z9aJRk2KTyN4=";

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
