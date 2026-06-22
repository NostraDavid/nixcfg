{
  lib,
  fetchurl,
  git,
  symlinkJoin,
  unstable,
  writeShellScriptBin,
}: let
  py = unstable.python313Packages;
  wheelBySystem = {
    "x86_64-linux" = {
      url = "https://files.pythonhosted.org/packages/86/f5/bab735d2c72ea55404b295d02d092644eb5f7cc6205e34d35eb9abfb9ab2/tiktoken-0.13.0-cp313-cp313-manylinux_2_28_x86_64.whl";
      hash = "sha256-XmNYkRyrSt7mcS2ifWVXNJak9oz4orX8pqStEPxXSM8=";
    };
    "aarch64-darwin" = {
      url = "https://files.pythonhosted.org/packages/53/61/c68e123b6d753e3fc2751e9b18e732c9d8bf1e1926762e736eee935d931c/tiktoken-0.13.0-cp313-cp313-macosx_11_0_arm64.whl";
      hash = "sha256-j+gGpQZk6Dpv/VbL0eT13MbNMqPnU49w3DixonE4RUU=";
    };
  };
  srcInfo = wheelBySystem.${unstable.stdenv.hostPlatform.system}
    or (throw "tiktoken: unsupported system ${unstable.stdenv.hostPlatform.system}");
  pythonPackage = py.buildPythonPackage rec {
    pname = "tiktoken";
    version = "0.13.0";
    format = "wheel";

    src = fetchurl {
      inherit (srcInfo) url hash;
    };

    dontStrip = true;

    propagatedBuildInputs = with py; [
      regex
      requests
    ];

    pythonImportsCheck = [
      "tiktoken"
    ];

    meta = with lib; {
      description = "Fast BPE tokeniser for use with OpenAI models";
      homepage = "https://github.com/openai/tiktoken";
      changelog = "https://github.com/openai/tiktoken/blob/main/CHANGELOG.md";
      license = licenses.mit;
      platforms = builtins.attrNames wheelBySystem;
    };
  };
  wrapper = writeShellScriptBin "tiktoken" ''
    export PYTHONPATH=${pythonPackage}/${py.python.sitePackages}
    export TIKTOKEN_GIT=${git}/bin/git
    exec ${py.python}/bin/python ${./tiktoken.py} "$@"
  '';
in
  symlinkJoin {
    name = "tiktoken-${pythonPackage.version}";
    paths = [
      pythonPackage
      wrapper
    ];

    meta =
      pythonPackage.meta
      // {
        description = "Pinned tiktoken Python package bundled with a tiktoken CLI wrapper";
        mainProgram = "tiktoken";
      };
  }
