{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
}:
buildNpmPackage (finalAttrs: {
  pname = "confluence-cli";
  version = "2.27.4";

  src = fetchurl {
    url = "https://registry.npmjs.org/confluence-cli/-/confluence-cli-${finalAttrs.version}.tgz";
    hash = "sha256-4oqag6kZjkjftaPutsvzeQkTLGBJhIeQUAdL1y0jf/E=";
  };
  sourceRoot = "package";

  postPatch = ''
    ${nodejs}/bin/node -e 'const fs = require("fs"); const pkg = require("./package.json"); delete pkg.devDependencies; fs.writeFileSync("package.json", JSON.stringify(pkg))'
  '';

  npmDepsHash = "sha256-XsV/6DH38h1QKA493oiGIOCv+oO9GUNba74J+1qtE84=";
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
