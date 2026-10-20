{
  autoPatchelfHook,
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  unstable,
}: let
  py = unstable.python313Packages;
  version = "0.41.0";
  isDarwin = stdenvNoCC.hostPlatform.isDarwin;

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

    src = fetchurl (
      if isDarwin
      then {
        url = "https://files.pythonhosted.org/packages/e9/38/aec1f450ae5c4796de8345442f297fcf8912c7d2e00a66d3236ff0f825ed/tree_sitter_language_pack-0.13.0-cp310-abi3-macosx_10_15_universal2.whl";
        hash = "sha256-Dn6ugStAotyKEusvXFXhMOuJJwagvuBiFd12r/6wDQc=";
      }
      else {
        url = "https://files.pythonhosted.org/packages/72/9d/644db031047ab1a70fc5cb6a79a4d4067080fac628375b2320752d2d7b58/tree_sitter_language_pack-0.13.0-cp310-abi3-manylinux2014_x86_64.whl";
        hash = "sha256-DU8mH844euBA2ufk0cGspj2EyIMgr8wJYcEjvsC+g3c=";
      }
    );

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

    src = fetchurl (
      if isDarwin
      then {
        url = "https://files.pythonhosted.org/packages/d7/37/8e62a5ecb8c433230586c3dbcbbbcfb519adb72e8a91d69f4dad5e0b3184/headroom_ai-0.41.0-cp310-abi3-macosx_11_0_arm64.whl";
        hash = "sha256-uELTbhYfnw0fxNVt4dhw4io+TQXJTSJy2aMGs49AYkI=";
      }
      else {
        url = "https://files.pythonhosted.org/packages/e5/37/dfd7a44720ffb0d233384d1337efaf211e4e975dd5880fee57facb83c841/headroom_ai-0.41.0-cp310-abi3-manylinux_2_28_x86_64.whl";
        hash = "sha256-9NteURmnOvPtlSscEMr/JDCDHYmesX2ZWidXSubmswY=";
      }
    );

    nativeBuildInputs = [makeWrapper] ++ lib.optionals (!isDarwin) [autoPatchelfHook];

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
      truststore
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
      platforms = ["x86_64-linux" "aarch64-darwin"];
    };
  }
