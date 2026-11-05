{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  curl,
  jq,
  coreutils,
  findutils,
  gnugrep,
  gnused,
}:
stdenvNoCC.mkDerivation {
  pname = "topdesk-cli";
  version = "0.1.0-unstable-2026-09-24";

  src = fetchFromGitHub {
    owner = "Bissbert";
    repo = "topdesk-cli";
    rev = "382572b0dd7084bba81b52e814b8825078a06881";
    hash = "sha256-VP7K938uZqQXpMqyPHZ34lmAYkPHAc8el412byrMN7s=";
  };

  nativeBuildInputs = [makeWrapper];
  makeFlags = ["PREFIX=$(out)"];
  dontBuild = true;

  postPatch = ''
    substituteInPlace bin/topdesk --replace-fail '-perm +111' '-perm -u=x'
  '';

  doCheck = true;
  nativeCheckInputs = [jq];
  checkPhase = ''
    runHook preCheck
    make test
    runHook postCheck
  '';

  postInstall = ''
    wrapProgram "$out/bin/topdesk" --prefix PATH : ${lib.makeBinPath [curl jq coreutils findutils gnugrep gnused]}
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/topdesk" --version | grep -F 'topdesk 0.1.0'
    "$out/bin/topdesk" incidents-create --help | grep -F 'Usage:'
    "$out/bin/topdesk" __commands | grep -Fx 'incidents-create'
    runHook postInstallCheck
  '';

  meta = {
    description = "Command-line client for the TOPdesk REST API";
    homepage = "https://github.com/Bissbert/topdesk-cli";
    license = lib.licenses.mit;
    mainProgram = "topdesk";
    platforms = lib.platforms.unix;
  };
}
