{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
}:
buildNpmPackage (finalAttrs: {
  pname = "confluence-cli";
  version = "2.31.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/confluence-cli/-/confluence-cli-${finalAttrs.version}.tgz";
    hash = "sha256-/N53xdGmFUTw3SXOriMh94zusycv8uLO6NBG2vDdN8Q=";
  };
  sourceRoot = "package";

  postPatch = ''
    ${nodejs}/bin/node -e 'const fs = require("fs"); const pkg = require("./package.json"); delete pkg.devDependencies; fs.writeFileSync("package.json", JSON.stringify(pkg))'
  '';

  npmDepsHash = "sha256-G8zk1LDlc5glEioMDFlPIbZqmru7p9X3ozRvCPM59aI=";
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
