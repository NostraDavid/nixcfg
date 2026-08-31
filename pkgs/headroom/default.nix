{
  autoPatchelfHook,
  fetchurl,
  lib,
  makeWrapper,
  unstable,
}: let
  py = unstable.python313Packages;
  version = "0.37.0";

  mcp = py.buildPythonPackage {
    pname = "mcp";
    version = "1.28.1";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/e2/5e/d118fce19f87a2e7d8101c35c8ae0ec289098a4df0ff244cec23e415aca0/mcp-1.28.1-py3-none-any.whl";
      hash = "sha256-Jya8pecZP2HF3eixJQCm3i2az20aHAvp6MLnBkN5kd8=";
    };

    dependencies = with py; [
      anyio
      httpx
      httpx-sse
      jsonschema
      pydantic
      pydantic-settings
      pyjwt
      python-dotenv
      python-multipart
      sse-starlette
      starlette
      typer
      typing-extensions
      typing-inspection
      uvicorn
      websockets
    ];

    pythonImportsCheck = ["mcp"];
  };

  tree-sitter-language-pack = py.buildPythonPackage {
    pname = "tree-sitter-language-pack";
    version = "0.13.0";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/72/9d/644db031047ab1a70fc5cb6a79a4d4067080fac628375b2320752d2d7b58/tree_sitter_language_pack-0.13.0-cp310-abi3-manylinux2014_x86_64.whl";
      hash = "sha256-DU8mH844euBA2ufk0cGspj2EyIMgr8wJYcEjvsC+g3c=";
    };

    dontStrip = true;
    dependencies = with py; [
      tree-sitter
      tree-sitter-c-sharp
      tree-sitter-embedded-template
      tree-sitter-yaml
    ];
    pythonImportsCheck = ["tree_sitter_language_pack"];
  };
in
  py.buildPythonApplication {
    pname = "headroom-ai";
    inherit version;
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/72/b8/16878cf4fe6fc390a0d22025b671468619db690ff14c1b103ace4b5e35f9/headroom_ai-0.37.0-cp310-abi3-manylinux_2_28_x86_64.whl";
      hash = "sha256-Lvxc32gaEMX8eionGkcRecQJB0U3BF9oKxDk1ySXb0Y=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    # Headroom's sandbox extra: its complete proxy/MCP feature set without
    # Torch-backed ML, image, voice, memory, and evaluation dependencies.
    dependencies = with py; [
      click
      fastapi
      fastembed
      h2
      httpx
      jinja2
      litellm
      magika
      numpy
      onnxruntime
      openai
      openpyxl
      opentelemetry-api
      opentelemetry-exporter-otlp-proto-http
      opentelemetry-sdk
      orjson
      pydantic
      pyyaml
      rich
      sqlite-vec
      tiktoken
      tomlkit
      trafilatura
      transformers
      tree-sitter
      uvicorn
      watchdog
      websockets
      xlrd
      zstandard
      mcp
      tree-sitter-language-pack
    ];

    # The upstream PyPI dependency only supplies ast-grep's executable. Nix
    # provides that executable directly and adds it to PATH below.
    pythonRemoveDeps = ["ast-grep-cli"];

    dontStrip = true;
    pythonImportsCheck = [
      "headroom"
      "headroom._core"
    ];

    postFixup = ''
      wrapProgram $out/bin/headroom \
        --unset _PYTHON_HOST_PLATFORM \
        --unset _PYTHON_SYSCONFIGDATA_NAME \
        --prefix PATH : ${lib.makeBinPath [unstable.ast-grep]}
    '';

    meta = {
      description = "Context compression layer for AI agents";
      homepage = "https://github.com/headroomlabs-ai/headroom";
      changelog = "https://github.com/headroomlabs-ai/headroom/releases/tag/v${version}";
      license = lib.licenses.asl20;
      mainProgram = "headroom";
      platforms = ["x86_64-linux"];
    };
  }
