# nix build .#github-copilot-cli
# note that future versions may break this process... Like 0.0.350!
{
  lib,
  buildNpmPackage,
  fetchzip,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "github-copilot-cli";
  version = "1.0.69";

  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${finalAttrs.version}.tgz";
    hash = "sha256-xKdOwHV+aUIKWB/SeZx9sVMCtJ7LkFOZiI61169QWlY=";
  };

  npmDepsHash = "sha256-nwq5jLKCRr0s3uiO9OBdu7eZQth4xL4FZVkXzUerF+Y=";

  npmConfigProduction = true;
  npmConfigOptional = false;
  npmFlags = [
    "--omit=dev"
  ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  passthru.updateScript = nix-update-script {extraArgs = ["--generate-lockfile"];};

  meta = {
    description = "GitHub Copilot CLI brings the power of Copilot coding agent directly to your terminal";
    homepage = "https://github.com/github/copilot-cli";
    changelog = "https://github.com/github/copilot-cli/releases/tag/v${finalAttrs.version}";
    downloadPage = "https://www.npmjs.com/package/@github/copilot";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "copilot";
  };
})
