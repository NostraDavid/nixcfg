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
  version = "0.1.5";

  src = fetchzip {
    url = "https://registry.npmjs.org/@openai/codex-security/-/codex-security-${finalAttrs.version}.tgz";
    hash = "sha256-lcoYA61o47zPV9I5ScvaSa9lIPygo0pQCQdZXmwfHrQ=";
  };

  npmDepsHash = "sha256-MTjjm/IMoLX4+klH+wzJ3aaOS6QgD437KgOcuFJBovI=";

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
