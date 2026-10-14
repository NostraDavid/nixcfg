{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
}:
buildNpmPackage (finalAttrs: {
  pname = "confluence-cli";
  version = "2.30.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/confluence-cli/-/confluence-cli-${finalAttrs.version}.tgz";
    hash = "sha256-FFXA00+RVpDd6SbxtsIrSmFWa3y3bMW9p86oAC6STM0=";
  };
  sourceRoot = "package";

  postPatch = ''
    ${nodejs}/bin/node -e 'const fs = require("fs"); const pkg = require("./package.json"); delete pkg.devDependencies; fs.writeFileSync("package.json", JSON.stringify(pkg))'
  '';

  npmDepsHash = "sha256-rlETMSdmqAb5D84526tVZ6v3go8xKtzCg8KD7DVDj1M=";
  npmConfigProduction = true;
  npmFlags = ["--omit=dev"];
  dontNpmBuild = true;

  meta = {
    description = "Command-line interface for Atlassian Confluence";
    homepage = "https://github.com/pchuri/confluence-cli";
    changelog = "https://github.com/pchuri/confluence-cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "confluence-cli";
    platforms = lib.platforms.unix;
  };
})
