{
  lib,
  buildNpmPackage,
  fetchzip,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "nanocoder";
  version = "1.14.2";

  src = fetchzip {
    url = "https://registry.npmjs.org/@nanocollective/nanocoder/-/nanocoder-${finalAttrs.version}.tgz";
    hash = "sha256-6Oc6wa78ynNkX5mgvNNNX9kpIIM+TQr1aRc4I73u0rg=";
  };

  npmDepsHash = "sha256-txlyhwPsN8E+ZULQY6xz4OeyGtNKkbLzoNjZAsdz4uo=";

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
    description = "Local-first CLI coding agent for Nano Collective workflows";
    homepage = "https://github.com/Nano-Collective/nanocoder";
    changelog = "https://github.com/Nano-Collective/nanocoder/releases/tag/v${finalAttrs.version}";
    downloadPage = "https://www.npmjs.com/package/@nanocollective/nanocoder";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "nanocoder";
  };
})
