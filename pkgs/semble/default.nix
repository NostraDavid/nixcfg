{
  lib,
  fetchFromGitHub,
  fetchPypi,
  python3Packages,
}: let
  bm25s = python3Packages.buildPythonPackage rec {
    pname = "bm25s";
    version = "0.3.9";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-iVxnnZUrfeg1XttfPhpiCh4vKU0dQrkZvwghzOLi9Zc=";
    };

    build-system = with python3Packages; [
      setuptools
    ];

    dependencies = with python3Packages; [
      numpy
    ];

    pythonImportsCheck = [
      "bm25s"
    ];
  };

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

  tree-sitter-language-pack = python3Packages.buildPythonPackage rec {
    pname = "tree-sitter-language-pack";
    version = "1.6.2";
    format = "wheel";

    src = fetchPypi {
      pname = "tree_sitter_language_pack";
      inherit version format;
      dist = "cp310";
      python = "cp310";
      abi = "abi3";
      platform = "manylinux_2_34_x86_64";
      hash = "sha256-IwXfeDXByz00txRQt50TWHi8JepdAtmYTO6GRgekrWA=";
    };

    dependencies = with python3Packages; [
      tree-sitter
    ];

    pythonImportsCheck = [
      "tree_sitter_language_pack"
    ];
  };
in
  python3Packages.buildPythonApplication rec {
    pname = "semble";
    version = "0.3.4";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "MinishLab";
      repo = "semble";
      rev = "e6afc1d7abe6e0d730f7fcb95d338973bc75f930";
      hash = "sha256-Mhco4G9p1V9RzOzwhu8yhawxIWBsjaWnqSJatGsMZXA=";
    };

    build-system = with python3Packages; [
      setuptools
      setuptools-scm
    ];

    dependencies = with python3Packages; [
      bm25s
      huggingface-hub
      mcp
      model2vec
      numpy
      orjson
      pathspec
      tree-sitter
      tree-sitter-language-pack
      vicinity
      watchfiles
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
      platforms = lib.platforms.linux;
    };
  }
