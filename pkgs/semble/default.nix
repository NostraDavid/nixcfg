{
  lib,
  fetchFromGitHub,
  fetchPypi,
  python3Packages,
}: let
  model2vec = python3Packages.buildPythonPackage rec {
    pname = "model2vec";
    version = "0.8.1";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-mjXTX2pETkzsGfICfuEGxUllzSa3/UpPACtfPitnd/Q=";
    };

    build-system = with python3Packages; [
      setuptools
      setuptools-scm
    ];

    dependencies = with python3Packages; [
      jinja2
      joblib
      numpy
      rich
      safetensors
      setuptools
      tokenizers
      tqdm
    ];

    pythonImportsCheck = [
      "model2vec"
    ];
  };

  vicinity = python3Packages.buildPythonPackage rec {
    pname = "vicinity";
    version = "0.4.4";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-Tg/+G7B4zkYE2nYn0vMgw52W0lKUhdDqpeLEyyuzKys=";
    };

    build-system = with python3Packages; [
      setuptools
      setuptools-scm
    ];

    dependencies = with python3Packages; [
      numpy
      orjson
      tqdm
    ];

    pythonImportsCheck = [
      "vicinity"
    ];
  };

  semble-grammars = python3Packages.buildPythonPackage rec {
    pname = "semble-grammars";
    version = "0.1.2";
    format = "wheel";

    src = fetchPypi {
      pname = "semble_grammars";
      inherit version format;
      dist = "py3";
      python = "py3";
      abi = "none";
      platform = "manylinux2014_x86_64";
      hash = "sha256-wEBZXKThF5aaNJgH3OBcGlHbs2joDegLAFU5/YbvnAc=";
    };

    dependencies = with python3Packages; [
      tree-sitter
    ];

    pythonImportsCheck = [
      "semble_grammars"
    ];
  };
in
  python3Packages.buildPythonApplication rec {
    pname = "semble";
    version = "0.5.6";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "MinishLab";
      repo = "semble";
      tag = "v${version}";
      hash = "sha256-pV/ermCbbGv8xJIjHNQcCzZBxkqmUBUaM6LZ7Sdues4=";
    };

    build-system = with python3Packages; [
      setuptools
      setuptools-scm
    ];

    dependencies = with python3Packages; [
      huggingface-hub
      mcp
      model2vec
      numpy
      orjson
      pathspec
      tree-sitter
      questionary
      semble-grammars
      vicinity
    ];

    pythonImportsCheck = [
      "semble"
    ];

    # An empty _PYTHON_SYSCONFIGDATA_NAME breaks Python's sysconfig import path.
    # This can leak in from interactive shells and causes semble to crash at startup.
    postFixup = ''
      wrapProgram $out/bin/semble \
        --unset _PYTHON_SYSCONFIGDATA_NAME
    '';

    meta = {
      description = "Fast and accurate code search for agents";
      homepage = "https://github.com/MinishLab/semble";
      license = lib.licenses.mit;
      mainProgram = "semble";
      platforms = ["x86_64-linux"];
    };
  }
