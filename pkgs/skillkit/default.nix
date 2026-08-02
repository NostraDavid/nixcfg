{
  lib,
  buildNpmPackage,
  fetchzip,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "skillkit";
  version = "1.24.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/skillkit/-/skillkit-${finalAttrs.version}.tgz";
    hash = "sha256-+3fwPiHc2JVS3IXYg87ynNCu6ivgLzLXvf12ra2qepY=";
  };

  npmDepsHash = "sha256-QT0tqUSsEfCfvQuuxvVpykEAXFSm799+6Twv2W1We50=";
  npmDepsFetcherVersion = 2;

  npmConfigProduction = true;
  npmFlags = [
    "--legacy-peer-deps"
    "--omit=dev"
  ];

  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  postInstall = ''
    substituteInPlace \
      $out/lib/node_modules/skillkit/node_modules/glob/node_modules/minimatch/dist/mjs/index.js \
      $out/lib/node_modules/skillkit/node_modules/minimatch/dist/esm/index.js \
      --replace-fail "import expand from 'brace-expansion';" "import { expand } from 'brace-expansion';"
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--generate-lockfile"];};

  meta = {
    description = "Portable skills manager for AI coding agents";
    homepage = "https://www.skillkit.sh/";
    changelog = "https://github.com/rohitg00/skillkit/releases/tag/v${finalAttrs.version}";
    downloadPage = "https://www.npmjs.com/package/skillkit";
    license = lib.licenses.asl20;
    mainProgram = "skillkit";
    platforms = lib.platforms.unix;
  };
})
