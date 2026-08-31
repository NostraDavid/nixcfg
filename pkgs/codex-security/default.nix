{
  buildNpmPackage,
  fetchzip,
  lib,
  makeWrapper,
  nix-update-script,
  nodejs_24,
  python3,
}:
buildNpmPackage (finalAttrs: {
  pname = "codex-security";
  version = "0.1.24";

  src = fetchzip {
    url = "https://registry.npmjs.org/@openai/codex-security/-/codex-security-${finalAttrs.version}.tgz";
    hash = "sha256-qtyG+pAZkpy+U2wNSytUoRowQIv35EGlnjwbreefhh4=";
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-wPxVQXTwrv7UtXl7VEzOr2iRtgi7e5bMCwACPPVkSxU=";

  npmConfigProduction = true;
  npmFlags = ["--omit=dev"];

  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  nativeBuildInputs = [makeWrapper];

  postInstall = ''
    rm $out/bin/codex-security
    makeWrapper ${nodejs_24}/bin/node $out/bin/codex-security \
      --add-flags "$out/lib/node_modules/@openai/codex-security/bin/codex-security.mjs" \
      --prefix PATH : ${lib.makeBinPath [python3]}
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--generate-lockfile"];};

  meta = {
    description = "TypeScript SDK and CLI for Codex Security";
    homepage = "https://developers.openai.com/codex/security";
    changelog = "https://github.com/openai/codex-security/releases/tag/npm-v${finalAttrs.version}";
    downloadPage = "https://www.npmjs.com/package/@openai/codex-security";
    license = lib.licenses.asl20;
    mainProgram = "codex-security";
    platforms = lib.platforms.unix;
  };
})
