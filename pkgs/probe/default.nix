{
  buildNpmPackage,
  lib,
  makeWrapper,
  nodejs_22,
}:
buildNpmPackage (finalAttrs: {
  pname = "probe";
  version = "0.6.0-rc325";

  src = ./.;
  npmDepsHash = "sha256-HSU6nu6smBxXu8u1KGDcINZrRT5Ui8/C6Psu6UrKcqI=";
  makeCacheWritable = true;

  dontNpmBuild = true;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/probe $out/bin
    cp -r node_modules $out/lib/probe/
    makeWrapper ${nodejs_22}/bin/node $out/bin/probe \
      --add-flags "$out/lib/probe/node_modules/@probelabs/probe/bin/probe"

    runHook postInstall
  '';

  meta = {
    description = "AST-aware semantic code search, agent, and MCP server";
    homepage = "https://github.com/probelabs/probe";
    changelog = "https://github.com/probelabs/probe/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "probe";
    platforms = ["x86_64-linux"];
  };
})
