{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_24,
}:
buildNpmPackage (finalAttrs: {
  pname = "elastic-cli";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "elastic";
    repo = "cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/w4qEeMgw0EFBe/F4GK+fkoJlj+Bc+IqPYZdmNxkeHw=";
  };
  nodejs = nodejs_24;
  npmDepsHash = "sha256-Ypq+rQntY7EV5LaWVyW+g5ccivwiumlPH/gpeI3bDxs=";
  postInstall = ''
    cp -r packages "$out/lib/node_modules/@elastic/cli/packages"
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$(HOME="$TMPDIR" "$out/bin/elastic" --version)" = "${finalAttrs.version}"
    HOME="$TMPDIR" "$out/bin/elastic" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Elastic Stack and Elastic Cloud command-line interface";
    homepage = "https://github.com/elastic/cli";
    license = lib.licenses.asl20;
    mainProgram = "elastic";
    platforms = lib.platforms.unix;
  };
})
