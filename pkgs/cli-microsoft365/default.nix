{
  lib,
  buildNpmPackage,
  fetchurl,
  stdenv,
  pkg-config,
  libsecret,
}:
buildNpmPackage (finalAttrs: {
  pname = "cli-microsoft365";
  version = "12.0.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@pnp/cli-microsoft365/-/cli-microsoft365-${finalAttrs.version}.tgz";
    hash = "sha256-j5bVytavBeuMD1vIW3+cQ6jN5aCRLxP0W2uafyH7iNQ=";
  };
  sourceRoot = "package";

  # Upstream omits registry URLs from its shrinkwrap. Use a normalized lockfile
  # so Nix can fetch every dependency reproducibly.
  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"follow-redirects": "1.16.0"' '"follow-redirects": "1.16.1"' \
      --replace-fail '"serialize-javascript": "7.0.5"' '"serialize-javascript": "7.1.4"' \
      --replace-fail '"adaptive-expressions": {' '"@actions/http-client": {"undici": "6.29.1"}, "adaptive-expressions": {'
    cp ${./package-lock.json} package-lock.json
    rm npm-shrinkwrap.json
  '';

  npmDepsHash = "sha256-Hv6F1E3ZpRNdNiPmMUsmKqZBACMTEMYsBsQBaeYO3R4=";
  npmConfigProduction = true;
  npmFlags = ["--omit=dev"];
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [pkg-config];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [libsecret];
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
