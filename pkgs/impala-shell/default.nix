{
  lib,
  fetchPypi,
  cyrus_sasl,
  python312Packages,
}: let
  py = python312Packages;

  python-sasl = py.buildPythonPackage rec {
    pname = "sasl";
    version = "0.3.1";
    format = "setuptools";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-BpUDCyP6plqrK0Ys5vBn1hyutAbeItHKf5JT/Z6+En4=";
    };

    nativeBuildInputs = [
      py.cython
      py.setuptools
    ];
    buildInputs = [cyrus_sasl];
    propagatedBuildInputs = [py.six];
    preBuild = ''
      cython --cplus -3 sasl/saslwrapper.pyx -o sasl/saslwrapper.cpp
    '';
    pythonImportsCheck = [];

    meta = with lib; {
      description = "Cyrus SASL bindings for Python";
      homepage = "https://github.com/cloudera/python-sasl";
      license = licenses.asl20;
      platforms = platforms.unix;
    };
  };

  pure-sasl = py.buildPythonPackage rec {
    pname = "pure-sasl";
    version = "0.6.2";
    format = "setuptools";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-U8E1X12pXiuFssyaavQ1UY7cIMgRk/qg7qZf3INROPQ=";
    };

    nativeBuildInputs = [py.setuptools];
    pythonImportsCheck = ["puresasl"];

    meta = with lib; {
      description = "Pure Python client SASL implementation";
      homepage = "https://github.com/thobbs/pure-sasl";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  };

  thrift-sasl = py.buildPythonPackage rec {
    pname = "thrift_sasl";
    version = "0.4.3";
    format = "setuptools";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-W91bdg2QoT2bOr/Ohz2wQlhhqo1r8lkS08wEZ6T3c9o=";
    };

    nativeBuildInputs = [py.setuptools];
    propagatedBuildInputs = [
      pure-sasl
      py.six
      py.thrift
    ];
    pythonImportsCheck = ["thrift_sasl"];

    meta = with lib; {
      description = "SASL transport for Thrift";
      homepage = "https://github.com/cloudera/thrift_sasl";
      license = licenses.asl20;
      platforms = platforms.unix;
    };
  };
in
  py.buildPythonApplication rec {
    pname = "impala-shell";
    version = "4.6.0";
    format = "setuptools";

    src = fetchPypi {
      pname = "impala_shell";
      inherit version;
      hash = "sha256-SeFkQZT35vfeWQo2h3mRvr9T8aWd2de3OlMniVuc5vw=";
    };

    nativeBuildInputs = [py.setuptools];

    propagatedBuildInputs = [
      py.bitarray
      py.configparser
      py.prettytable
      py.pykerberos
      py.six
      py.sqlparse
      py.thrift
      python-sasl
      thrift-sasl
    ];

    doCheck = false;
    pythonImportsCheck = ["impala_shell"];

    meta = with lib; {
      description = "Apache Impala interactive shell";
      homepage = "https://pypi.org/project/impala-shell/";
      license = licenses.asl20;
      mainProgram = "impala-shell";
      maintainers = [];
      platforms = platforms.unix;
    };
  }
