{
  lib,
  fetchFromGitHub,
  makeWrapper,
  python3Packages,
}:
python3Packages.buildPythonPackage rec {
  pname = "python-token-killer";
  version = "0.2.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "amahi2001";
    repo = "python-token-killer";
    rev = "v${version}";
    hash = "sha256-Ts1RRm8CDzuwru0w5b0yA9Cf1qswUghhO9I67KOfMBA=";
  };

  build-system = [python3Packages.hatchling];

  nativeBuildInputs = [makeWrapper];
  nativeCheckInputs = [python3Packages.pytestCheckHook];

  postInstall = ''
    install -Dm644 ${./ptk.py} "$out/share/python-token-killer/cli.py"
    makeWrapper ${python3Packages.python.interpreter} "$out/bin/ptk" \
      --add-flags "$out/share/python-token-killer/cli.py" \
      --prefix PYTHONPATH : "$out/${python3Packages.python.sitePackages}"
  '';

  pythonImportsCheck = ["ptk"];

  meta = {
    description = "Minimize LLM tokens from Python objects, code, logs, and diffs, with a CLI";
    homepage = "https://github.com/amahi2001/python-token-killer";
    changelog = "https://github.com/amahi2001/python-token-killer/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "ptk";
    platforms = lib.platforms.all;
  };
}
