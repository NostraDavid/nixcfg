{
  lib,
  buildNpmPackage,
  fetchurl,
}:
buildNpmPackage (finalAttrs: {
  pname = "cli-microsoft365";
  version = "11.11.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@pnp/cli-microsoft365/-/cli-microsoft365-${finalAttrs.version}.tgz";
    hash = "sha256-RdtTd3szeKVXSqNqLRRMuHKsyoPFYJt4q1mBBR59LRc=";
  };
  sourceRoot = "package";

  # Upstream omits registry URLs from its shrinkwrap. Use a normalized lockfile
  # so Nix can fetch every dependency reproducibly.
  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"follow-redirects": "1.16.0"' '"follow-redirects": "1.16.1"'
    cp ${./package-lock.json} package-lock.json
    rm npm-shrinkwrap.json
  '';

  npmDepsHash = "sha256-d5Iw+5w2O2i073d+BKtMyOak8W7IQyhPcs4rwZv5zeY=";
  npmConfigProduction = true;
  npmFlags = ["--omit=dev"];
  dontNpmBuild = true;

  meta = {
    description = "CLI for Microsoft 365, including SharePoint and Viva Engage";
    homepage = "https://pnp.github.io/cli-microsoft365/";
    changelog = "https://github.com/pnp/cli-microsoft365/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "m365";
    platforms = lib.platforms.unix;
  };
})
