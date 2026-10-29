{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
}:
buildNpmPackage (finalAttrs: {
  pname = "confluence-cli";
  version = "2.30.5";

  src = fetchurl {
    url = "https://registry.npmjs.org/confluence-cli/-/confluence-cli-${finalAttrs.version}.tgz";
    hash = "sha256-3A+NCbTHKNH687YIO6d+WvTK8BtIHKCw7y0THUgA120=";
  };
  sourceRoot = "package";

  postPatch = ''
    ${nodejs}/bin/node -e 'const fs = require("fs"); const pkg = require("./package.json"); delete pkg.devDependencies; fs.writeFileSync("package.json", JSON.stringify(pkg))'
  '';

  npmDepsHash = "sha256-kYx1X44A0leamPJW2tWZe7pkeBenNbF/TekwmEnuieo=";
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
