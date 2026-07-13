{
  lib,
  fetchPypi,
  nix-update-script,
  unstable,
}: let
  inherit (unstable) python3Packages;
  beautifulsoup4 = python3Packages.beautifulsoup4.overridePythonAttrs (_old: rec {
    version = "4.15.0";
    src = fetchPypi {
      pname = "beautifulsoup4";
      inherit version;
      hash = "sha256-KI48p9VLBvKsGRlwvCdcGTnLRtRQslW/ZxiwSqN6tPc=";
    };
    patches = [];
    doCheck = false;
    nativeCheckInputs = [];
  });
  fastapi = python3Packages.fastapi.overridePythonAttrs (_old: rec {
    version = "0.138.1";
    src = fetchPypi {
      pname = "fastapi";
      inherit version;
      hash = "sha256-luNwLc4J7g3OSIVhNWINPYZcpoSnn+dRP9exOhL4KGI=";
    };
    doCheck = false;
    nativeCheckInputs = [];
  });
  markdownItPy = python3Packages.markdown-it-py.overridePythonAttrs (_old: rec {
    version = "4.2.0";
    src = fetchPypi {
      pname = "markdown_it_py";
      inherit version;
      hash = "sha256-BKIWgdb7tiPeU/bzZNNSMJ1AlN1BlAQKEP1Rgz5BjUk=";
    };
    doCheck = false;
    nativeCheckInputs = [];
  });
  pathspec = python3Packages.pathspec.overridePythonAttrs (_old: rec {
    version = "1.1.1";
    src = fetchPypi {
      pname = "pathspec";
      inherit version;
      hash = "sha256-F9tezVJBBKEg4XOBTJA2epapjQfEWy4QwvORn/+Rv1o=";
    };
    doCheck = false;
    nativeCheckInputs = [];
  });
  pythonFrontmatter = python3Packages.python-frontmatter.overridePythonAttrs (_old: rec {
    version = "1.3.0";
    pyproject = true;
    format = null;
    src = fetchPypi {
      pname = "python_frontmatter";
      inherit version;
      hash = "sha256-rMc+R3pWjcKiXJ4TDGxoro2qjCBMj36BPbR9anKA3PI=";
    };
    build-system = [
      python3Packages.uv-build
    ];
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail "uv_build>=0.11.15,<0.12" "uv_build>=0.10,<0.12"
    '';
    doCheck = false;
    nativeCheckInputs = [];
  });
  uvicorn = python3Packages.uvicorn.overridePythonAttrs (_old: rec {
    version = "0.49.0";
    src = fetchPypi {
      pname = "uvicorn";
      inherit version;
      hash = "sha256-6/QnGqWA2d6X+TGS1FlRdt9ukfmq6RnKc+T8B98eZqM=";
    };
    doCheck = false;
    nativeCheckInputs = [];
  });
  replacePythonDep = pname: replacement:
    builtins.map (dep:
      if (dep.pname or null) == pname
      then replacement
      else dep);
  mcp = python3Packages.mcp.overridePythonAttrs (old: {
    dependencies = replacePythonDep "uvicorn" uvicorn (old.dependencies or []);
  });
  claudeAgentSdk = python3Packages.claude-agent-sdk.overridePythonAttrs (old: {
    dependencies = replacePythonDep "mcp" mcp (old.dependencies or []);
  });
  almanacYoke = python3Packages.buildPythonPackage rec {
    pname = "almanac-yoke";
    version = "0.1.7";
    pyproject = true;

    src = fetchPypi {
      pname = "almanac_yoke";
      inherit version;
      hash = "sha256-aHbkHb71gNmffC4vHk0dJEpiDB2Nq3byqlCXrwmgRBA=";
    };

    build-system = [python3Packages.hatchling];

    dependencies = with python3Packages; [
      claudeAgentSdk
      jsonschema
      pydantic
      pyyaml
    ];

    pythonImportsCheck = ["yoke"];
  };
in
  python3Packages.buildPythonApplication rec {
    pname = "codealmanac";
    version = "0.4.4";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-GL8VDorwp5KzNWoatQ+g6YfkzDhyHDoBY5LZeE5pXnM=";
    };

    build-system = with python3Packages; [
      setuptools
    ];

    dependencies = [
      almanacYoke
      beautifulsoup4
      python3Packages.charset-normalizer
      claudeAgentSdk
      fastapi
      python3Packages.httpx
      python3Packages.humanfriendly
      python3Packages.jsonlines
      markdownItPy
      pathspec
      python3Packages.psutil
      python3Packages.pydantic
      python3Packages.pydantic-settings
      pythonFrontmatter
      python3Packages.pyyaml
      python3Packages.ruamel-yaml
      uvicorn
    ];

    pythonImportsCheck = [
      "codealmanac"
    ];

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      $out/bin/codealmanac --help >/dev/null

      runHook postInstallCheck
    '';

    passthru.updateScript = nix-update-script {
      extraArgs = ["--flake"];
    };

    meta = {
      description = "Local codebase wiki maintained by AI coding agents";
      homepage = "https://github.com/AlmanacCode/codealmanac";
      downloadPage = "https://pypi.org/project/codealmanac/";
      license = lib.licenses.asl20;
      mainProgram = "codealmanac";
      platforms = lib.platforms.all;
    };
  }
