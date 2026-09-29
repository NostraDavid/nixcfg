{
  lib,
  buildNpmPackage,
  fetchurl,
}:
buildNpmPackage (finalAttrs: {
  pname = "confluence-cli";
  version = "2.25.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/confluence-cli/-/confluence-cli-${finalAttrs.version}.tgz";
    hash = "sha256-e1tw/4WEJLh8QP++HZc2wVZa6cGjeNVfJYYCNgWh28k=";
  };
  sourceRoot = "package";

  postPatch = ''
    node -e 'const fs = require("fs"); const pkg = require("./package.json"); delete pkg.devDependencies; fs.writeFileSync("package.json", JSON.stringify(pkg))'
  '';

  npmDepsHash = "sha256-d7mLLM91i0mqm2nBdL+paNIA6aguSyfOOXhpti6Keu8=";
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
