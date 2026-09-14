{
  fetchFromGitHub,
  fetchurl,
  lib,
  linkFarm,
  model2vec,
  python3Packages,
}:
python3Packages.buildPythonApplication rec {
  pname = "engrim";
  version = "1.4.5";
  pyproject = true;
  src = fetchFromGitHub {
    owner = "timgordontg";
    repo = "engrim";
    tag = "v${version}";
    hash = "sha256-EU00xCrSJop5h/WyB2VjREtwg2UrEtz/0d1I6DMqMlY=";
  };
  build-system = [python3Packages.setuptools];
  dependencies = [model2vec];
  passthru.model = import ./model.nix {inherit fetchurl linkFarm;};
  makeWrapperArgs = ["--set-default ENGRIM_EMBED_MODEL ${passthru.model}"];
  nativeCheckInputs = [python3Packages.pytestCheckHook];
  env.ENGRIM_EMBED = "off";
  pythonImportsCheck = ["engrim" "engrim.mcp_server"];
  meta = {
    description = "Project-scoped episodic memory and MCP server for coding agents";
    homepage = "https://github.com/timgordontg/engrim";
    license = lib.licenses.mit;
    mainProgram = "engrim";
  };
}
