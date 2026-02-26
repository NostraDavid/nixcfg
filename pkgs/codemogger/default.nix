{
  lib,
  buildNpmPackage,
  fetchzip,
}:
buildNpmPackage (finalAttrs: {
  pname = "codemogger";
  version = "0.1.2";

  src = fetchzip {
    url = "https://registry.npmjs.org/codemogger/-/codemogger-${finalAttrs.version}.tgz";
    hash = "sha256-5LAIgAP5buvzo27zHh1w2KbgOpgF6SoG2CnA2FQtPr0=";
  };

  npmDepsHash = "sha256-982gTzips3bAUbcdNU1rubbIZkamB1ExFNegGeBiEds=";

  npmConfigProduction = true;
  npmConfigOptional = false;
  npmConfigIgnoreScripts = true;
  npmRebuildFlags = [
    "--ignore-scripts"
  ];
  npmFlags = [
    "--omit=dev"
  ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  meta = {
    description = "Code indexing library with tree-sitter chunking and vector+FTS search for AI coding agents";
    homepage = "https://github.com/glommer/codemogger";
    downloadPage = "https://www.npmjs.com/package/codemogger";
    license = lib.licenses.mit;
    mainProgram = "codemogger";
  };
})
