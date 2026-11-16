{
  buildNpmPackage,
  chromium,
  fetchFromGitHub,
  lib,
  makeWrapper,
}:
buildNpmPackage (finalAttrs: {
  pname = "playwright-cli";
  version = "0.1.24";
  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-7dKRvxQ+ntqr4JPqGoWN+CHEZVg6E6Q/hO6EA6DXDKA=";
  };
  npmDepsHash = "sha256-MWBo2GleWToU5Z7c6njOIWaWzcmokY5wf6FRxHqw4H4=";
  npmFlags = ["--omit=dev"];
  dontNpmBuild = true;
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  nativeBuildInputs = [makeWrapper];

  postInstall = ''
    wrapProgram "$out/bin/playwright-cli" \
      --set NO_UPDATE_NOTIFIER 1 \
      --set-default PLAYWRIGHT_MCP_BROWSER chromium \
      --set-default PLAYWRIGHT_MCP_EXECUTABLE_PATH ${lib.getExe chromium}
    mkdir -p "$out/share/skills"
    cp -r skills/playwright-cli "$out/share/skills/"
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/playwright-cli" --version | grep -F '${finalAttrs.version}'
    "$out/bin/playwright-cli" --help > /dev/null
    test -s "$out/share/skills/playwright-cli/SKILL.md"
    runHook postInstallCheck
  '';
  meta = {
    description = "Playwright browser automation CLI with its official agent skill";
    homepage = "https://github.com/microsoft/playwright-cli";
    license = lib.licenses.asl20;
    mainProgram = "playwright-cli";
    platforms = lib.platforms.linux;
  };
})
