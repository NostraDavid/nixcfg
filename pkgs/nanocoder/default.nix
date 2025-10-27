{
  lib,
  buildNpmPackage,
  fetchzip,
  nix-update-script,
}:

buildNpmPackage (finalAttrs: {
  pname = "nanocoder";
  version = "1.14.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@nanocollective/nanocoder/-/nanocoder-${finalAttrs.version}.tgz";
    hash = "sha256-GQTryj34NslrFHA8W3IkcSjASmc/cYskd8R9DlAPNbQ=";
  };

  npmDepsHash = "sha256-c566+lRQUEwynf+k9oMvM8s76VHvLi8i/8vo2j33Pos=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  passthru.updateScript = nix-update-script { extraArgs = [ "--generate-lockfile" ]; };

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
    platforms = lib.platforms.linux;
  };
})
