{
  lib,
  git,
  fetchurl,
  symlinkJoin,
  unstable,
  writeShellScriptBin,
}: let
  py = unstable.python313Packages;
  version = "0.14.0";
  wheelBySystem = {
    "x86_64-linux" = {
      url = "https://files.pythonhosted.org/packages/37/62/cae690d9783146b0f81f564ada0f8f611de68178c0c9c7e1e969f0516b48/tiktoken-${version}-cp313-cp313-manylinux_2_28_x86_64.whl";
      hash = "sha256-JuYPapVu4XGrcos3uEOZBdfqHbQ1ww+YIvKR6YYchh0=";
    };
    "aarch64-darwin" = {
      url = "https://files.pythonhosted.org/packages/ad/5f/6448cfe278c3664ba9ec5b5ac08344341f7dc3d42888476e215a14eda2be/tiktoken-${version}-cp313-cp313-macosx_11_0_arm64.whl";
      hash = "sha256-y+LMO7qTm82vED4D351QOdM4hwgLMVYkvijsaQWeX5Q=";
    };
  };
  srcInfo = wheelBySystem.${unstable.stdenv.hostPlatform.system}
    or (throw "tiktoken: unsupported system ${unstable.stdenv.hostPlatform.system}");
  pythonPackage = py.buildPythonPackage rec {
    pname = "tiktoken";
    inherit version;
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
  pythonEnv = unstable.python313.withPackages (_: [pythonPackage]);
  wrapper = writeShellScriptBin "tiktoken" ''
    export PATH="${lib.makeBinPath [git]}:$PATH"
    exec ${pythonEnv}/bin/python ${./tiktoken.py} "$@"
  '';
in
  symlinkJoin rec {
    pname = "tiktoken";
    inherit version;
    name = "${pname}-${version}";
    # The wrapper embeds its Python environment; exporting pythonPackage here
    # would collide with the copy already pulled in by LiteLLM.
    paths = [wrapper];

    passthru.updateScript = ../../cmd/update-tiktoken.sh;

    meta =
      pythonPackage.meta
      // {
        description = "Pinned tiktoken Python package bundled with a tiktoken CLI wrapper";
        mainProgram = "tiktoken";
      };
  }
