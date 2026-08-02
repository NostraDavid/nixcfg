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
  npmDepsHash = "sha256-QWbZLO2QR7/g4X+S8FqUkJHoyru84a7aOZ5PspDPhXE=";
  npmRebuildFlags = ["--ignore-scripts"];
  makeCacheWritable = true;

  dontNpmBuild = true;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    substituteInPlace \
      node_modules/@probelabs/probe/build/downloader.js \
      node_modules/@probelabs/probe/build/extractor.js \
      node_modules/@probelabs/probe/src/downloader.js \
      node_modules/@probelabs/probe/src/extractor.js \
      --replace-fail "import tar from 'tar';" "import * as tar from 'tar';"
    (
      cd node_modules/@probelabs/probe
      node scripts/postinstall.js
    )

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
