{
  buildNpmPackage,
  chromium,
  fetchFromGitHub,
  lib,
  makeWrapper,
}:
buildNpmPackage (finalAttrs: {
  pname = "playwright-cli";
  version = "0.1.23";
  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-MqeB9U8676YOlB6JbX5Dcp2PeWftQcmbTUPp9dS5t+U=";
  };
  npmDepsHash = "sha256-GQjH0Zwf9cYuuM6m4mM2Xwz6qWuJTsXsj0nCSm71BlY=";
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
