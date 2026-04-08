{
  lib,
  buildNpmPackage,
  fetchzip,
}:
buildNpmPackage (finalAttrs: {
  pname = "codemogger";
  version = "0.1.4";

  src = fetchzip {
    url = "https://registry.npmjs.org/codemogger/-/codemogger-${finalAttrs.version}.tgz";
    hash = "sha256-81W6YA4lzptJ0luL0tQONKM3lRH87mPOWD2XBXxF1g4=";
  };

  npmDepsHash = "sha256-oDqHUfqk5gpdeY3QGYzLdxRhjmNWW9Bvfwr0anOrNOM=";

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
